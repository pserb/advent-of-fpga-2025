open! Core
open! Hardcaml
open! Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; data : 'a [@bits 8]
    ; valid : 'a [@bits 1]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { ready : 'a [@bits 1]
    ; p1 : 'a [@bits 16]
    ; p2 : 'a [@bits 16]
    }
  [@@deriving hardcaml]
end

module Instruction = struct
  type 'a t =
    { is_left : 'a
    ; is_right : 'a
    ; is_digit : 'a
    ; is_delim : 'a
    ; digit : 'a [@bits 10]
    }
  [@@deriving hardcaml]
end

let parse_instruction scope (data : Signal.t) : Signal.t Instruction.t =
  let open Char in
  let%hw is_left = data ==:. to_int 'L' in
  let%hw is_right = data ==:. to_int 'R' in
  let%hw is_digit = data >=:. to_int '0' &: (data <=:. to_int '9') in
  let%hw is_delim = data ==:. to_int ' ' |: (data ==:. to_int '\n') in
  let%hw digit = uresize (data -:. to_int '0') ~width:10 in
  { Instruction.is_left; is_right; is_digit; is_delim; digit }
;;

(* We need x mod 100 and x / 100, but hardware dividers are expensive. Instead,
   we ask: "how many times does 100 fit into x?" We check each threshold
   (100, 200, ... 1000) and count how many x exceeds. That count is the quotient.
   Then we just subtract (quotient * 100) from x to get the remainder.

   We only need 10 thresholds because the max input is 99 + 999 = 1098 (dial
   position 0-99, max rotation distance 999), so quotient never exceeds 10.

   Example: x = 350
   - x >= 100? yes (count 1)
   - x >= 200? yes (count 2)
   - x >= 300? yes (count 3)
   - x >= 400? no
   So quotient = 3, remainder = 350 - 300 = 50 *)
let divmod_100 scope (x : Signal.t) : Signal.t * Signal.t =
  let%hw x in
  let%hw_list remainders =
    List.init 11 ~f:(fun n -> uresize (x -:. (n * 100)) ~width:7)
  in
  let%hw_list thresholds =
    List.init 10 ~f:(fun i -> uresize (x >=:. (i + 1) * 100) ~width:4)
  in
  let%hw quotient = tree ~arity:2 ~f:(List.reduce_exn ~f:( +: )) thresholds in
  let%hw remainder = mux quotient remainders in
  quotient, remainder
;;

let compute_rotation scope ~dial ~distance ~direction : Signal.t * Signal.t =
  (* Right rotation: add distance to position, then mod 100. We use 11 bits
     because the max sum is 99 + 999 = 1098. The quotient = zero crossings. *)
  let%hw right_sum = uresize dial ~width:11 +: uresize distance ~width:11 in
  let%hw right_crossings, right_pos = divmod_100 scope right_sum in

  (* Left rotation is trickier because (position - distance) can go negative,
     and hardware doesn't handle negative mod nicely. The trick: add a bias
     to keep things positive, do the mod, then adjust the result.

     Why 999? It's exactly the max rotation distance, so (dial + 999 - distance)
     is always >= 0. After mod 100, we get a "shifted" remainder that we fix up:
     - remainder 99 actually means position 0
     - otherwise, add 1 to get the real position

     For zero crossings: we start with 10 (the bias contributes 9-10 fake
     crossings depending on dial position), subtract the quotient, and subtract
     1 extra if we started at position 0 (leaving zero shouldn't count as
     crossing it). *)
  let%hw left_biased =
    uresize dial ~width:11 +: of_int_trunc ~width:11 999 -: uresize distance ~width:11
  in
  let%hw left_quot, left_rem = divmod_100 scope left_biased in
  let%hw left_crossings =
    of_int_trunc ~width:4 10 -: left_quot -: uresize (dial ==:. 0) ~width:4
  in
  let%hw left_pos = mux2 (left_rem ==:. 99) (zero 7) (uresize left_rem ~width:7 +:. 1) in

  let%hw crossings = mux2 direction right_crossings (uresize left_crossings ~width:4) in
  let%hw next_pos = mux2 direction right_pos left_pos in
  next_pos, crossings
;;

let create scope (i : Signal.t I.t) : Signal.t O.t =
  let open Always in
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let%hw_var dial =
    Variable.reg spec ~enable:vdd ~width:7 ~clear_to:(of_unsigned_int ~width:7 50)
  in
  let%hw_var direction = Variable.reg spec ~enable:vdd ~width:1 in
  let%hw_var distance = Variable.reg spec ~enable:vdd ~width:10 in
  let%hw_var p1 = Variable.reg spec ~enable:vdd ~width:16 in
  let%hw_var p2 = Variable.reg spec ~enable:vdd ~width:16 in
  (* We defer the p1 increment by one cycle using this flag. Why? It breaks the
     critical path: instead of `divmod -> compare -> add` all in one cycle, we
     register the comparison result and do the add next cycle. Saves ~0.2ns/cycle. *)
  let%hw_var landed_on_zero = Variable.reg spec ~enable:vdd ~width:1 in
  let%hw.Instruction.Of_signal instr = parse_instruction scope i.data in
  (* Accumulate digits: distance = distance * 10 + new_digit
     We compute *10 as (x << 3) + (x << 1) = 8x + 2x *)
  let%hw next_distance =
    sll distance.value ~by:3 +: sll distance.value ~by:1 +: instr.digit
  in
  let%hw next_pos, crossings =
    compute_rotation
      scope
      ~dial:dial.value
      ~distance:distance.value
      ~direction:direction.value
  in
  compile
    [ when_
        i.valid
        [ when_ instr.is_left [ direction <-- gnd; distance <-- zero 10 ]
        ; when_ instr.is_right [ direction <-- vdd; distance <-- zero 10 ]
        ; when_ instr.is_digit [ distance <-- next_distance ]
        ; when_
            instr.is_delim
            [ dial <-- next_pos
            ; p2 <-- p2.value +: uresize crossings ~width:16
            ; landed_on_zero <-- uresize (next_pos ==:. 0) ~width:1
            ]
        ; when_ landed_on_zero.value [ p1 <-- p1.value +:. 1; landed_on_zero <-- gnd ]
        ]
    ];
  { O.ready = vdd; p1 = p1.value; p2 = p2.value }
;;

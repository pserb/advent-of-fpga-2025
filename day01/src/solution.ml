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
    ; done_ : 'a [@bits 1] (* optional *)
    }
  [@@deriving hardcaml]
end

let divmod_100 (x : Signal.t) : Signal.t * Signal.t =
  let remainders = List.init 11 ~f:(fun q -> uresize (x -:. (q * 100)) ~width:7) in
  let quotient =
    priority_select_with_default
      (List.init 10 ~f:(fun i ->
         let q = 10 - i in
         { With_valid.valid = x >=:. q * 100; value = of_int_trunc ~width:4 q }))
      ~default:(of_int_trunc ~width:4 0)
  in
  let remainder = mux quotient remainders in
  quotient, remainder
;;

let create (i : Signal.t I.t) : Signal.t O.t =
  let open Always in
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  (* registers *)
  let pos = Variable.reg spec ~enable:vdd ~width:7 ~clear_to:(of_unsigned_int ~width:7 50) in
  let dir = Variable.reg spec ~enable:vdd ~width:1 in
  let accum = Variable.reg spec ~enable:vdd ~width:10 in
  let p1 = Variable.reg spec ~enable:vdd ~width:16 in
  let p2 = Variable.reg spec ~enable:vdd ~width:16 in
  (* sing bytes *)
  let byte = i.data in
  let is_L = byte ==:. Char.to_int 'L' in
  let is_R = byte ==:. Char.to_int 'R' in
  let is_digit = byte >=:. 0x30 &: (byte <=:. 0x39) in
  let is_delim = byte ==:. 0x20 |: (byte ==:. 0x0A) (* space or newline *) in
  let digit_val = uresize (byte -:. 0x30) ~width:10 in
  let accum_times_10 = sll (Variable.value accum) ~by:3 +: sll (Variable.value accum) ~by:1 in
  let accum_next = accum_times_10 +: digit_val in
  let pos_val = Variable.value pos in
  let accum_val = Variable.value accum in
  (* right path *)
  let right_raw = uresize pos_val ~width:11 +: uresize accum_val ~width:11 in
  let right_wraps, right_new_pos = divmod_100 right_raw in
  (* left path *)
  let left_biased =
    uresize pos_val ~width:11 +: of_int_trunc ~width:11 999 -: uresize accum_val ~width:11
  in
  let left_quot, left_rem = divmod_100 left_biased in
  let left_wraps =
    of_int_trunc ~width:4 10 -: left_quot -: uresize (pos_val ==:. 0) ~width:4
  in
  let left_new_pos = mux2 (left_rem ==:. 99) (zero 7) (uresize left_rem ~width:7 +:. 1) in
  (* select based on dir *)
  let dir_val = Variable.value dir in
  let cmd_wraps = mux2 dir_val right_wraps (uresize left_wraps ~width:4) in
  let cmd_new_pos = mux2 dir_val right_new_pos left_new_pos in
  (* always block *)
  compile
    [ when_
        i.valid
        [ when_ is_L [ dir <-- gnd; accum <-- zero 10 ]
        ; when_ is_R [ dir <-- vdd; accum <-- zero 10 ]
        ; when_ is_digit [ accum <-- accum_next ]
        ; when_
            is_delim
            [ pos <-- cmd_new_pos
            ; p2 <-- Variable.value p2 +: uresize cmd_wraps ~width:16
            ; when_ (cmd_new_pos ==:. 0) [ p1 <-- Variable.value p1 +:. 1 ]
            ]
        ]
    ];
  (* output *)
  { O.ready = vdd; p1 = Variable.value p1; p2 = Variable.value p2; done_ = gnd }
;;

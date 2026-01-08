open! Core
open! Hardcaml
open! Signal

(* Processes one [low, high] range per cycle. For each range, we compute in
   parallel the sum of all invalid IDs from 13 pattern families using arithmetic
   series. The triangular formula avoids enumeration:
     sum = n * first + step * (n-1)*n/2

   Constants in Solution_constants define each family:
   - step: distance between consecutive invalid IDs (e.g., 101 for 1212→1313)
   - start_val/end_val: bounds for that digit-length pattern
   - in_p1: include in Part 1 (exact 2x repetition only)
   - sign: +1 or -1 for inclusion-exclusion (Part 2 has overlapping families)

   The 13 families break down as:
   - Part 1 (5): 2x repetition - steps 11, 101, 1001, 10001, 100001
   - Part 2 (6): 3+x repetition - steps 111, 11111, 10101, 1111111, 1001001, 101010101
   - Overlap (2): subtracted to avoid double-counting - steps 111111, 1111111111

   Division uses reciprocal multiplication: x / step = (x * recip) >> 56, where
   recip = ceil(2^56 / step).

   Input arrives pre-parsed: the sim layer converts "4242-80085132,..." text into
   (low, high) pairs sent one per cycle. *)
open! Solution_constants

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; range_low : 'a [@bits 34]
    ; range_high : 'a [@bits 34]
    ; valid : 'a
    ; last : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { ready : 'a
    ; done_ : 'a
    ; p1 : 'a [@bits sum_bits]
    ; p2 : 'a [@bits sum_bits]
    }
  [@@deriving hardcaml]
end

(* optimize division using reciprocal multiplication *)
(* floor(x / step) *)
let floor_div scope ~dividend ~reciprocal =
  let%hw recip = of_int64_trunc ~width:recip_width reciprocal in
  let%hw product = dividend *: recip in
  let%hw result = uresize (srl product ~by:recip_shift) ~width:id_bits in
  result
;;

(* ceil(x / step) = floor((x + step - 1) / step) *)
let ceil_div scope ~step ~dividend ~reciprocal =
  let%hw adjusted_dividend = dividend +: uresize step ~width:id_bits -:. 1 in
  floor_div scope ~dividend:adjusted_dividend ~reciprocal
;;

(* contribution from a single constant for a given range 
   returns the sum of all invalid IDs in the range
*)
let compute_contribution scope ~config ~low ~high =
  let step_width = if config.step > (1 lsl 17) - 1 then 31 else 17 in
  let%hw step_sig = of_int_trunc ~width:step_width config.step in
  let%hw start_sig = of_int64_trunc ~width:id_bits (Int64.of_int config.start_val) in
  let%hw end_sig = of_int64_trunc ~width:id_bits config.end_val in
  (* lower_bound = max(ceil(low / step) * step, start) *)
  let%hw lower_bound =
    let ceil_quotient =
      ceil_div scope ~step:step_sig ~dividend:low ~reciprocal:config.reciprocal
    in
    let first_multiple = uresize (ceil_quotient *: step_sig) ~width:id_bits in
    mux2 (first_multiple >=: start_sig) first_multiple start_sig
  in
  (* upper_bound = min(high, end) *)
  let%hw upper_bound = mux2 (high <=: end_sig) high end_sig in
  (* check if range is valid *)
  let%hw valid_range = lower_bound <=: upper_bound in
  (* contribution = (n_invalid_ids * lower_bound) + (step * triangular_number) *)
  let%hw contribution =
    (* n_invalid_ids = (upper_bound - lower_bound) / step + 1 *)
    let n_invalid_ids =
      let quotient =
        floor_div
          scope
          ~dividend:(upper_bound -: lower_bound)
          ~reciprocal:config.reciprocal
      in
      quotient +:. 1
    in
    (* triangular_number = n_invalid_ids * (n_invalid_ids - 1) / 2 *)
    let triangular_number = srl (n_invalid_ids *: (n_invalid_ids -:. 1)) ~by:1 in
    uresize (n_invalid_ids *: lower_bound) ~width:sum_bits
    +: uresize (step_sig *: triangular_number) ~width:sum_bits
  in
  (* return 0 if range invalid, otherwise contribution *)
  let%hw result = mux2 valid_range contribution (zero sum_bits) in
  result
;;

let create scope (i : Signal.t I.t) : Signal.t O.t =
  let open Always in
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let%hw_var is_done = Variable.reg spec ~enable:vdd ~width:1 in
  let%hw_var p1 = Variable.reg spec ~enable:vdd ~width:sum_bits in
  let%hw_var p2 = Variable.reg spec ~enable:vdd ~width:sum_bits in
  let%hw_array contributions =
    Array.map all_constants ~f:(fun config ->
      compute_contribution scope ~config ~low:i.range_low ~high:i.range_high)
  in
  let%hw p1_contribution =
    contributions
    |> Array.filteri ~f:(fun idx _ -> all_constants.(idx).in_p1)
    |> Array.to_list
    |> Signal.tree ~arity:2 ~f:(Signal.reduce ~f:( +: ))
  in
  let%hw p2_contribution =
    let sum select_sign =
      contributions
      |> Array.filteri ~f:(fun idx _ -> select_sign all_constants.(idx).sign)
      |> Array.to_list
      |> Signal.tree ~arity:2 ~f:(Signal.reduce ~f:( +: ))
    in
    sum (fun s -> s > 0) -: sum (fun s -> s < 0)
  in
  let%hw ready = ~:(is_done.value) in
  let%hw accept = i.valid &: ready in
  compile
    [ when_
        accept
        [ p1 <-- p1.value +: p1_contribution
        ; p2 <-- p2.value +: p2_contribution
        ; when_ i.last [ is_done <--. 1 ]
        ]
    ];
  { O.ready; done_ = is_done.value; p1 = p1.value; p2 = p2.value }
;;

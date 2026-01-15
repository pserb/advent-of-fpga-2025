open! Core
open! Hardcaml
open! Signal

let bank_size = 100
let k_p1 = 2
let k_p2 = 12

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; data : 'a [@bits 8]
    ; valid : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { ready : 'a
    ; p1 : 'a [@bits 48]
    ; p2 : 'a [@bits 48]
    }
  [@@deriving hardcaml]
end

(* monotonic stack with parallel operations
   stack[0] = first pushed
   stack[size-1] = last pushed *)
module Mono_stack = struct
  let create ~spec ~k ~digit ~digit_valid ~digit_idx ~bank_done =
    let open Always in
    let stack = Array.init k ~f:(fun _ -> Variable.reg spec ~enable:vdd ~width:4) in
    let stack_size = Variable.reg spec ~enable:vdd ~width:5 in
    let stack_size_v = Variable.value stack_size in
    let stack_vals = Array.map stack ~f:Variable.value in
    let remaining = of_int_trunc ~width:7 bank_size -: digit_idx in
    (* for each position i, can we pop it if we're at the back?
       we can pop position if:
       1. stack[i] < digit (current digit is larger)
       2. i + remaining >= k (we can still fill k slots with remaining digits) *)
    let can_pop_at =
      Array.init k ~f:(fun i ->
        let smaller = stack_vals.(i) <: digit in
        let can_refill = of_int_trunc ~width:8 i +: uresize remaining ~width:8 >=:. k in
        smaller &: can_refill)
    in
    (* find the new stack size after popping
       we pop the suffix of the stack starting from some position pop_start
       pop_start = min position where all positions from pop_start to size-1 can be popped

       for each position i, is the entire suffix [i, k) poppable? *)
    let suffix_poppable =
      Array.init (k + 1) ~f:(fun start ->
        if start >= k
        then vdd (* empty suffix *)
        else
          Array.sub can_pop_at ~pos:start ~len:(k - start)
          |> Array.to_list
          |> List.reduce_exn ~f:( &: ))
    in
    (* find the smallest i such that suffix [i, size) is poppable AND i < size
       this is the new size after popping *)
    let new_size_after_pop =
      let options =
        List.init (k + 1) ~f:(fun i ->
          let i_sig = of_int_trunc ~width:5 i in
          let valid_pop_point = i_sig <: stack_size_v &: suffix_poppable.(i) in
          valid_pop_point, i_sig)
      in
      List.fold options ~init:stack_size_v ~f:(fun acc (valid, i) ->
        mux2 (valid &: (i <: acc)) i acc)
    in
    let should_push = new_size_after_pop <:. k in
    let new_size = mux2 should_push (new_size_after_pop +:. 1) new_size_after_pop in
    let new_stack_vals =
      Array.init k ~f:(fun i ->
        let i_sig = of_int_trunc ~width:5 i in
        let keep_existing = i_sig <: new_size_after_pop in
        let insert_here = should_push &: (i_sig ==: new_size_after_pop) in
        mux2 insert_here digit (mux2 keep_existing stack_vals.(i) (zero 4)))
    in
    let result =
      Array.foldi stack ~init:(zero 48) ~f:(fun i acc reg ->
        let place_value =
          match k - 1 - i with
          | 0 -> of_int_trunc ~width:48 1
          | 1 -> of_int_trunc ~width:48 10
          | 2 -> of_int_trunc ~width:48 100
          | 3 -> of_int_trunc ~width:48 1000
          | 4 -> of_int_trunc ~width:48 10000
          | 5 -> of_int_trunc ~width:48 100000
          | 6 -> of_int_trunc ~width:48 1000000
          | 7 -> of_int_trunc ~width:48 10000000
          | 8 -> of_int_trunc ~width:48 100000000
          | 9 -> of_int_trunc ~width:48 1000000000
          | 10 -> of_int_trunc ~width:48 10000000000
          | 11 -> of_int_trunc ~width:48 100000000000
          | _ -> zero 48
        in
        let contribution =
          sel_bottom (uresize (Variable.value reg) ~width:48 *: place_value) ~width:48
        in
        acc +: contribution)
    in
    let update_stack =
      List.mapi (Array.to_list stack) ~f:(fun i reg -> reg <-- new_stack_vals.(i))
      @ [ stack_size <-- new_size ]
    in
    let reset =
      [ stack_size <--. 0 ] @ List.map (Array.to_list stack) ~f:(fun r -> r <--. 0)
    in
    let logic =
      [ when_ bank_done reset; when_ (digit_valid &: ~:bank_done) update_stack ]
    in
    logic, result
  ;;
end

let create _scope (i : Signal.t I.t) : Signal.t O.t =
  let open Always in
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let p1_acc = Variable.reg spec ~enable:vdd ~width:48 in
  let p2_acc = Variable.reg spec ~enable:vdd ~width:48 in
  let is_digit = i.data >=:. Char.to_int '0' &: (i.data <=:. Char.to_int '9') in
  let is_newline = i.data ==:. Char.to_int '\n' in
  let digit = sel_bottom (i.data -:. Char.to_int '0') ~width:4 in
  let digit_idx = Variable.reg spec ~enable:vdd ~width:7 in
  let digit_idx_v = Variable.value digit_idx in
  let digit_valid = i.valid &: is_digit in
  let bank_done = i.valid &: is_newline in
  let p1_logic, p1_result =
    Mono_stack.create ~spec ~k:k_p1 ~digit ~digit_valid ~digit_idx:digit_idx_v ~bank_done
  in
  let p2_logic, p2_result =
    Mono_stack.create ~spec ~k:k_p2 ~digit ~digit_valid ~digit_idx:digit_idx_v ~bank_done
  in
  compile
    (p1_logic
     @ p2_logic
     @ [ when_ digit_valid [ digit_idx <-- digit_idx_v +:. 1 ]
       ; when_
           bank_done
           [ digit_idx <--. 0
           ; p1_acc <-- Variable.value p1_acc +: p1_result
           ; p2_acc <-- Variable.value p2_acc +: p2_result
           ]
       ]);
  { O.ready = vdd; p1 = Variable.value p1_acc; p2 = Variable.value p2_acc }
;;

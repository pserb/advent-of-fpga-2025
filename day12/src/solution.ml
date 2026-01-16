open! Core
open! Hardcaml
open! Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; line : 'a [@bits Parser.line_bytes * 8]
    ; valid : 'a
    ; last : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { ready : 'a
    ; done_ : 'a
    ; result : 'a [@bits 16]
    }
  [@@deriving hardcaml]
end

let create scope (i : Signal.t I.t) : Signal.t O.t =
  let open Always in
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let%hw_var is_done = Variable.reg spec ~enable:vdd ~width:1 in
  let%hw_var result = Variable.reg spec ~enable:vdd ~width:16 in
  let parsed = Parser.parse ~line:i.line in
  let total =
    parsed.presents
    |> List.map ~f:(uresize ~width:10)
    |> tree ~arity:2 ~f:(reduce ~f:( +: ))
  in
  let area = uresize (parsed.width *: parsed.height) ~width:14 in
  let fits = uresize (total *: of_int_trunc ~width:4 9) ~width:14 <=: area in
  let%hw ready = ~:(is_done.value) in
  compile
    [ when_
        (i.valid &: ready)
        [ when_ fits [ result <-- result.value +:. 1 ]; when_ i.last [ is_done <--. 1 ] ]
    ];
  { O.ready; done_ = is_done.value; result = result.value }
;;

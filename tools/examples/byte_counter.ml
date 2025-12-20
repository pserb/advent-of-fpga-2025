(* https://github.com/janestreet/hardcaml/blob/master/docs/fibonacci_example.md *)

open! Core
open! Hardcaml
open Signal

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
    ; count : 'a [@bits 32]
    }
  [@@deriving hardcaml]
end

let create (i : Signal.t I.t) =
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let ready = vdd in
  let transfer = i.valid &: ready in
  let count = reg_fb spec ~width:32 ~f:(fun count -> mux2 transfer (count +:. 1) count) in
  { O.ready; count }
;;

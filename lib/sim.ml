open! Core
open! Hardcaml

module Byte_stream = struct
  module I = struct
    type 'a t =
      { data : 'a [@bits 8]
      ; valid : 'a [@bits 1]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = { ready : 'a [@bits 1] } [@@deriving hardcaml]
  end
end

(* https://ocaml.org/manual/5.2/api/In_channel.html *)
let file_to_bytes filename =
  In_channel.read_all filename |> String.to_list |> List.map ~f:Char.to_int
;;

let send_byte_step
  ~bytes
  ~(i : Bits.t ref Byte_stream.I.t)
  ~(o : Bits.t ref Byte_stream.O.t)
  =
  match bytes with
  | [] ->
    i.valid := Bits.gnd;
    []
  | byte :: rest ->
    i.valid := Bits.vdd;
    i.data := Bits.of_int_trunc ~width:8 byte;
    if Bits.to_bool !(o.ready) then rest else bytes
;;

(* https://ocaml.org/manual/5.2/api/In_channel.html *)

open! Core

let file_to_bytes filename =
  In_channel.read_all filename |> String.to_list |> List.map ~f:Char.to_int
;;

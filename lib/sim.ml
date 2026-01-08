open! Core
open! Hardcaml

(* used for day01 *)
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

(* end used for day01 *)

(* used for day02 *)
module Range_stream = struct
  module I = struct
    type 'a t =
      { range_low : 'a [@bits 34]
      ; range_high : 'a [@bits 34]
      ; valid : 'a [@bits 1]
      ; last : 'a [@bits 1]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = { ready : 'a [@bits 1] } [@@deriving hardcaml]
  end
end

let file_to_ranges filename =
  let content = In_channel.read_all filename |> String.strip in
  String.split content ~on:','
  |> List.map ~f:(fun range_str ->
    match String.split (String.strip range_str) ~on:'-' with
    | [ low; high ] -> Int64.of_string low, Int64.of_string high
    | _ -> failwith ("Invalid range format: " ^ range_str))
;;

let send_range_step
  ~ranges
  ~(i : Bits.t ref Range_stream.I.t)
  ~(o : Bits.t ref Range_stream.O.t)
  =
  match ranges with
  | [] ->
    i.valid := Bits.gnd;
    i.last := Bits.gnd;
    []
  | [ (low, high) ] ->
    (* Last range *)
    i.valid := Bits.vdd;
    i.last := Bits.vdd;
    i.range_low := Bits.of_int64_trunc ~width:34 low;
    i.range_high := Bits.of_int64_trunc ~width:34 high;
    if Bits.to_bool !(o.ready) then [] else ranges
  | (low, high) :: rest ->
    i.valid := Bits.vdd;
    i.last := Bits.gnd;
    i.range_low := Bits.of_int64_trunc ~width:34 low;
    i.range_high := Bits.of_int64_trunc ~width:34 high;
    if Bits.to_bool !(o.ready) then rest else ranges
;;
(* end used for day02 *)

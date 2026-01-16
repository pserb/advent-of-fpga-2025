open! Core
open! Hardcaml
open! Signal

(* ASCII line parser for Day 12 input format: "WxH: P0 P1 P2 P3 P4 P5"
   All dimensions are 2 digits (35-50), all presents are 2 digits (10-83).
   and these positions are known at compile time, simplifying logic *)

let line_bytes = 32

module Parsed = struct
  type 'a t =
    { width : 'a
    ; height : 'a
    ; presents : 'a list
    }
end

let get_byte ~line ~pos =
  let start_bit = (line_bytes - 1 - pos) * 8 in
  select line ~high:(start_bit + 7) ~low:start_bit
;;

let digit ~line ~pos =
  uresize (get_byte ~line ~pos -: of_int_trunc ~width:8 (Char.to_int '0')) ~width:8
;;

let parse_2digit ~line ~pos =
  let d0 = digit ~line ~pos in
  let d1 = digit ~line ~pos:(pos + 1) in
  uresize (d0 *: of_int_trunc ~width:4 10) ~width:8 +: d1
;;

let parse ~line : Signal.t Parsed.t =
  (* fixed positions based on format "WxH: P0 P1 P2 P3 P4 P5" *)
  let width = parse_2digit ~line ~pos:0 in
  let height = parse_2digit ~line ~pos:3 in
  let presents =
    List.map [ 7; 10; 13; 16; 19; 22 ] ~f:(fun pos -> parse_2digit ~line ~pos)
  in
  { width; height; presents }
;;

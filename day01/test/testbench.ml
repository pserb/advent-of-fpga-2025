open! Core
open! Hardcaml
open Bits

module type Solution = sig
  module I : sig
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; data : 'a
      ; valid : 'a
      }

    include Interface.S with type 'a t := 'a t
  end

  module O : sig
    type 'a t =
      { ready : 'a
      ; p1 : 'a
      ; p2 : 'a
      ; done_ : 'a
      }

    include Interface.S with type 'a t := 'a t
  end

  val create : Signal.t I.t -> Signal.t O.t
end

let run_simulation (module S : Solution) ~bytes : int * int =
  let module Simulator = Cyclesim.With_interface (S.I) (S.O) in
  let sim = Simulator.create S.create in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  inputs.clear := vdd;
  inputs.valid := gnd;
  inputs.data := zero 8;
  Cyclesim.cycle sim;
  inputs.clear := gnd;
  let stream_i : Bits.t ref Sim.Byte_stream.I.t =
    { data = inputs.data; valid = inputs.valid }
  in
  let stream_o : Bits.t ref Sim.Byte_stream.O.t = { ready = outputs.ready } in
  let rec feed_bytes = function
    | [] -> ()
    | bytes ->
      let remaining = Sim.send_byte_step ~bytes ~i:stream_i ~o:stream_o in
      Cyclesim.cycle sim;
      feed_bytes remaining
  in
  feed_bytes bytes;
  inputs.valid := gnd;
  Cyclesim.cycle sim;
  to_int_trunc !(outputs.p1), to_int_trunc !(outputs.p2)
;;

let%expect_test "test day01" =
  let bytes = Sim.file_to_bytes "../../inputs/day01.txt" in
  let p1, p2 = run_simulation (module Day01.Solution) ~bytes in
  printf "Part 1: %d\nPart 2: %d\n" p1 p2;
  [%expect {|
    Part 1: 1129
    Part 2: 6638
    |}]
;;

(* let%expect_test "test day01 v2" =
  let bytes = Sim.file_to_bytes "../../inputs/day01.txt" in
  let p1, p2 = run_simulation (module Day01.Solution_v2) ~bytes in
  printf "Part 1: %d\nPart 2: %d\n" p1 p2;
  [%expect {|
    Part 1: 1129
    Part 2: 6638
    |}]
;; *)

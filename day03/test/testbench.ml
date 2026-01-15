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
      }

    include Interface.S with type 'a t := 'a t
  end

  val create : Scope.t -> Signal.t I.t -> Signal.t O.t
end

let run_simulation (module S : Solution) ~bytes : int * int64 * int64 =
  let module Simulator = Cyclesim.With_interface (S.I) (S.O) in
  let scope = Scope.create ~flatten_design:true () in
  let sim = Simulator.create (S.create scope) in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  let cycles = ref 0 in
  inputs.clear := vdd;
  inputs.valid := gnd;
  inputs.data := zero 8;
  Cyclesim.cycle sim;
  Int.incr cycles;
  inputs.clear := gnd;
  List.iter bytes ~f:(fun byte ->
    inputs.data := of_int_trunc ~width:8 byte;
    inputs.valid := vdd;
    Cyclesim.cycle sim;
    Int.incr cycles);
  inputs.valid := gnd;
  Cyclesim.cycle sim;
  Int.incr cycles;
  !cycles, to_int64_trunc !(outputs.p1), to_int64_trunc !(outputs.p2)
;;

let%expect_test "test day03 actual input" =
  let bytes = Sim.file_to_bytes "../../inputs/day03.txt" in
  let cycles, p1, p2 = run_simulation (module Day03.Solution) ~bytes in
  printf "Cycles: %d\nPart 1: %Ld\nPart 2: %Ld\n" cycles p1 p2;
  [%expect {|
    Cycles: 20202
    Part 1: 17301
    Part 2: 172162399742349
    |}]
;;

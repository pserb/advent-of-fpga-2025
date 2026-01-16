open! Core
open! Hardcaml
open Bits
module Simulator = Cyclesim.With_interface (Day12.Solution.I) (Day12.Solution.O)

let run_simulation ~lines =
  let scope = Scope.create ~flatten_design:true () in
  let sim = Simulator.create (Day12.Solution.create scope) in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  let line_bits = Day12.Parser.line_bytes * 8 in
  inputs.clear := vdd;
  inputs.valid := gnd;
  inputs.last := gnd;
  inputs.line := zero line_bits;
  Cyclesim.cycle sim;
  inputs.clear := gnd;
  let cycles = ref 0 in
  let rec feed = function
    | [] -> ()
    | [ line ] ->
      inputs.valid := vdd;
      inputs.last := vdd;
      inputs.line := Sim.string_to_bits ~width:Day12.Parser.line_bytes line;
      Cyclesim.cycle sim;
      Int.incr cycles
    | line :: rest ->
      inputs.valid := vdd;
      inputs.last := gnd;
      inputs.line := Sim.string_to_bits ~width:Day12.Parser.line_bytes line;
      Cyclesim.cycle sim;
      Int.incr cycles;
      feed rest
  in
  feed lines;
  inputs.valid := gnd;
  while not (to_bool !(outputs.done_)) do
    Cyclesim.cycle sim;
    Int.incr cycles
  done;
  let result = to_int_trunc !(outputs.result) in
  !cycles, result
;;

let%expect_test "test day12 with actual input" =
  let lines = Sim.file_to_lines "../../inputs/day12.txt" in
  let cycles, result = run_simulation ~lines in
  printf "Cycles: %d\n" cycles;
  printf "Part 1: %d\n" result;
  [%expect {|
    Cycles: 1000
    Part 1: 595
    |}]
;;

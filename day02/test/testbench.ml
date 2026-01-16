open! Core
open! Hardcaml
open Bits
module Simulator = Cyclesim.With_interface (Day02.Solution.I) (Day02.Solution.O)

let run_simulation ~ranges =
  let scope = Scope.create ~flatten_design:true () in
  let sim = Simulator.create (Day02.Solution.create scope) in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  (* Reset *)
  inputs.clear := vdd;
  inputs.valid := gnd;
  inputs.last := gnd;
  inputs.range_low := zero 34;
  inputs.range_high := zero 34;
  Cyclesim.cycle sim;
  inputs.clear := gnd;
  (* Stream ranges *)
  let stream_i : Bits.t ref Sim.Range_stream.I.t =
    { range_low = inputs.range_low
    ; range_high = inputs.range_high
    ; valid = inputs.valid
    ; last = inputs.last
    }
  in
  let stream_o : Bits.t ref Sim.Range_stream.O.t = { ready = outputs.ready } in
  let cycles = ref 0 in
  let rec feed_ranges = function
    | [] -> ()
    | ranges ->
      let remaining = Sim.send_range_step ~ranges ~i:stream_i ~o:stream_o in
      Cyclesim.cycle sim;
      Int.incr cycles;
      feed_ranges remaining
  in
  feed_ranges ranges;
  (* Wait for done *)
  inputs.valid := gnd;
  while not (to_bool !(outputs.done_)) do
    Cyclesim.cycle sim;
    Int.incr cycles
  done;
  let p1 = to_int64_trunc !(outputs.p1) in
  let p2 = to_int64_trunc !(outputs.p2) in
  !cycles, p1, p2
;;

let%expect_test "test day02 with actual input" =
  let ranges = Sim.file_to_ranges "../../inputs/day02.txt" in
  let cycles, p1, p2 = run_simulation ~ranges in
  printf "Cycles: %d\n" cycles;
  printf "Part 1: %Ld\n" p1;
  printf "Part 2: %Ld\n" p2;
  (* Expected from Python solution:
     Part 1: 16793817782
     Part 2: 27469417404 *)
  [%expect {|
    Cycles: 28
    Part 1: 16793817782
    Part 2: 27469417404
    |}]
;;

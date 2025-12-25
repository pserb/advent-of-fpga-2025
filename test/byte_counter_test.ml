(* https://github.com/janestreet/hardcaml/blob/master/docs/fibonacci_example.md *)

(* NOTE:
 this is not a proper hardware testbench with unit testing
 currently just meant as a proof of concept and sanity check for parsing AoC inputs

 dune exec test/byte_counter_test.exe
*)

open! Core
open! Hardcaml

let input_filename = "inputs/day01.txt"

let byte_counter_testbench () =
  (* build circuit *)
  let module Simulator = Cyclesim.With_interface (Byte_counter.I) (Byte_counter.O) in
  let sim = Simulator.create Byte_counter.create in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  (* load data *)
  let bytes = Sim.file_to_bytes input_filename in
  printf "loaded %d bytes\n" (List.length bytes);
  (* build sender view of ports *)
  let sender_i : Bits.t ref Sim.Byte_stream.I.t = { data = i.data; valid = i.valid } in
  let sender_o : Bits.t ref Sim.Byte_stream.O.t = { ready = o.ready } in
  (* sim *)
  let rec run_cycles bytes cycle_count =
    let bytes = Sim.send_byte_step ~bytes ~i:sender_i ~o:sender_o in
    Cyclesim.cycle sim;
    if List.is_empty bytes then cycle_count + 1 else run_cycles bytes (cycle_count + 1)
  in
  (* init and run *)
  i.clear := Bits.vdd;
  Cyclesim.cycle sim;
  i.clear := Bits.gnd;
  let cycles = run_cycles bytes 0 in
  let final_count = Bits.to_int_trunc !(o.count) in
  printf "sim complete:\n";
  printf "  bytes sent: %d\n" (List.length (Sim.file_to_bytes input_filename));
  printf "  bytes counted by hardware: %d\n" final_count;
  printf "  cycles: %d\n" cycles
;;

let () = byte_counter_testbench ()

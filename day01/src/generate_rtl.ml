open! Core
open! Hardcaml

(* Usage: generate_rtl
   Outputs Verilog to stdout - redirect to file as needed *)

let () =
  let which = if Array.length (Sys.get_argv ()) > 1 then (Sys.get_argv ()).(1) else "" in
  match which with
  (* | "v2" ->
    let module C = Circuit.With_interface (Day01.Solution_v2.I) (Day01.Solution_v2.O) in
    let circuit = C.create_exn ~name:"day01_v2" Day01.Solution_v2.create in
    Rtl.print Verilog circuit *)
  | _ ->
    let module C = Circuit.With_interface (Day01.Solution.I) (Day01.Solution.O) in
    let circuit = C.create_exn ~name:"day01" Day01.Solution.create in
    Rtl.print Verilog circuit
;;

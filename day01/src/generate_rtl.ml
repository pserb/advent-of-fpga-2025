open! Core
open! Hardcaml

let () =
  let module C = Circuit.With_interface (Day01.Solution.I) (Day01.Solution.O) in
  let scope = Scope.create ~flatten_design:true () in
  let circuit = C.create_exn ~name:"day01" (Day01.Solution.create scope) in
  Rtl.print Verilog circuit
;;

open! Core
open! Hardcaml

let () =
  let module C = Circuit.With_interface (Day12.Solution.I) (Day12.Solution.O) in
  let scope = Scope.create ~flatten_design:true () in
  let circuit = C.create_exn ~name:"day12" (Day12.Solution.create scope) in
  Rtl.print Verilog circuit
;;

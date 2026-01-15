open! Core
open! Hardcaml

let () =
  let module C = Circuit.With_interface (Day03.Solution.I) (Day03.Solution.O) in
  let scope = Scope.create ~flatten_design:true () in
  let circuit = C.create_exn ~name:"day03" (Day03.Solution.create scope) in
  Rtl.print Verilog circuit
;;

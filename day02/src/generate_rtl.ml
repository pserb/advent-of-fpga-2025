open! Core
open! Hardcaml

let () =
  let module C = Circuit.With_interface (Day02.Solution.I) (Day02.Solution.O) in
  let scope = Scope.create ~flatten_design:true () in
  let circuit = C.create_exn ~name:"day02" (Day02.Solution.create scope) in
  Rtl.print Verilog circuit
;;

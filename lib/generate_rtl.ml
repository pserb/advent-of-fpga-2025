open! Core
open! Hardcaml

module type S = sig
  module I : Hardcaml.Interface.S
  module O : Hardcaml.Interface.S

  val create : Scope.t -> Signal.t I.t -> Signal.t O.t
end

let generate name (module S : S) =
  let module C = Circuit.With_interface (S.I) (S.O) in
  let scope = Scope.create ~flatten_design:true () in
  let circuit = C.create_exn ~name (S.create scope) in
  Rtl.print Verilog circuit
;;

let () =
  let day = (Sys.get_argv ()).(1) in
  match day with
  | "day01" -> generate "day01" (module Day01.Solution)
  | "day02" -> generate "day02" (module Day02.Solution)
  | "day03" -> generate "day03" (module Day03.Solution)
  | "day12" -> generate "day12" (module Day12.Solution)
  | _ -> failwith ("Unknown day: " ^ day)
;;

open! Core
open! Hardcaml

module I = struct
  type 'a t =
    { data : 'a [@bits 8]
    ; valid : 'a [@bits 1]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { ready : 'a [@bits 1] } [@@deriving hardcaml]
end

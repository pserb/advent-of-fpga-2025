open! Hardcaml

module I : sig
  type 'a t =
    { data : 'a
    ; valid : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { ready : 'a } [@@deriving hardcaml]
end

open! Hardcaml

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; data : 'a
    ; valid : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { ready : 'a
    ; count : 'a
    }
  [@@deriving hardcaml]
end

val create : Signal.t I.t -> Signal.t O.t

open! Hardcaml

module Byte_stream : sig
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
end

val file_to_bytes : string -> int list

val send_byte_step
  :  bytes:int list
  -> i:Bits.t ref Byte_stream.I.t
  -> o:Bits.t ref Byte_stream.O.t
  -> int list

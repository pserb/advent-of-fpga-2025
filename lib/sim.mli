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

module Range_stream : sig
  module I : sig
    type 'a t =
      { range_low : 'a
      ; range_high : 'a
      ; valid : 'a
      ; last : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = { ready : 'a } [@@deriving hardcaml]
  end
end

val file_to_ranges : string -> (int64 * int64) list

val send_range_step
  :  ranges:(int64 * int64) list
  -> i:Bits.t ref Range_stream.I.t
  -> o:Bits.t ref Range_stream.O.t
  -> (int64 * int64) list

val file_to_lines : string -> string list
val string_to_bits : width:int -> string -> Bits.t

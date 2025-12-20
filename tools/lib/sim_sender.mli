open! Hardcaml

val send_byte_step
  :  bytes:int list
  -> i:Bits.t ref Byte_stream.I.t
  -> o:Bits.t ref Byte_stream.O.t
  -> int list

open! Hardcaml

let send_byte_step
  ~bytes
  ~(i : Bits.t ref Byte_stream.I.t)
  ~(o : Bits.t ref Byte_stream.O.t)
  =
  match bytes with
  | [] ->
    i.valid := Bits.gnd;
    []
  | byte :: rest ->
    i.valid := Bits.vdd;
    i.data := Bits.of_int_trunc ~width:8 byte;
    if Bits.to_bool !(o.ready) then rest else bytes
;;

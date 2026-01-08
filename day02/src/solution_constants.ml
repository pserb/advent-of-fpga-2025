let id_bits = 34
let sum_bits = 48
let recip_shift = 56
let recip_width = 53

type constant_config =
  { step : int
  ; start_val : int
  ; end_val : int64
  ; in_p1 : bool
  ; sign : int
  ; reciprocal : int64 (* ceil(2^56 / step) *)
  }

let all_constants =
  [| (* Part 1: add to p1, add to p2 *)
     { step = 11
     ; start_val = 11
     ; end_val = 99L
     ; in_p1 = true
     ; sign = 1
     ; reciprocal = 6550690367084358L
     }
   ; { step = 101
     ; start_val = 1010
     ; end_val = 9999L
     ; in_p1 = true
     ; sign = 1
     ; reciprocal = 713441525128000L
     }
   ; { step = 1001
     ; start_val = 100100
     ; end_val = 999999L
     ; in_p1 = true
     ; sign = 1
     ; reciprocal = 71985608429499L
     }
   ; { step = 10001
     ; start_val = 10001000
     ; end_val = 99999999L
     ; in_p1 = true
     ; sign = 1
     ; reciprocal = 7205038899903L
     }
   ; { step = 100001
     ; start_val = 1000010000
     ; end_val = 9999999999L
     ; in_p1 = true
     ; sign = 1
     ; reciprocal = 720568734692L
     }
   ; (* Part 2: skip p1, add to p2 *)
     { step = 111
     ; start_val = 111
     ; end_val = 999L
     ; in_p1 = false
     ; sign = 1
     ; reciprocal = 649167513855207L
     }
   ; { step = 11111
     ; start_val = 11111
     ; end_val = 99999L
     ; in_p1 = false
     ; sign = 1
     ; reciprocal = 6485248315897L
     }
   ; { step = 10101
     ; start_val = 101010
     ; end_val = 999999L
     ; in_p1 = false
     ; sign = 1
     ; reciprocal = 7133708943464L
     }
   ; { step = 1111111
     ; start_val = 1111111
     ; end_val = 9999999L
     ; in_p1 = false
     ; sign = 1
     ; reciprocal = 64851841120L
     }
   ; { step = 1001001
     ; start_val = 100100100
     ; end_val = 999999999L
     ; in_p1 = false
     ; sign = 1
     ; reciprocal = 71985536516L
     }
   ; { step = 101010101
     ; start_val = 1010101010
     ; end_val = 9999999999L
     ; in_p1 = false
     ; sign = 1
     ; reciprocal = 713370182L
     }
   ; (* Overlap: skip p1, subtract from p2 *)
     { step = 111111
     ; start_val = 111111
     ; end_val = 999999L
     ; in_p1 = false
     ; sign = -1
     ; reciprocal = 648518994861L
     }
   ; { step = 1111111111
     ; start_val = 1111111111
     ; end_val = 9999999999L
     ; in_p1 = false
     ; sign = -1
     ; reciprocal = 64851835L
     }
  |]
;;

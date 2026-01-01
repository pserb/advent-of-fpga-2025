# Advent of FPGA 2025

A Jane Street challenge: \
https://blog.janestreet.com/advent-of-fpga-challenge-2025/

Written in Hardcaml \
Docs: https://www.janestreet.com/web-app/hardcaml-docs/introduction/why

Targeting AMD Artix 7 FPGA (XC7A50T-1FGG484C)

| | |
|---|---|
| **Logic Cells** | 52K |
| **LUTs / FFs** | 32.6K / 65.2K |
| **Block RAM** | 2.7 Mb (75× 36Kb) |
| **DSP Slices** | 120 (25×18 MAC) |
| **User I/O** | 250 |
| **GTP Transceivers** | 4 (up to 3.75 Gb/s) |
| **PCIe** | Gen2 ×4 |

## I/O
Problem inputs are converted to an int list of bytes, which are sent one byte per clock cycle. This is to keep focus on the solution-solving hardware. Optimally, instead packets of data would be sent once per cycle, each packet problem-specific. \
*e.g. for day 1, each packet would contain dial rotation (L50, R42, etc.)*

Part 1 and 2 solutions are output.

## Solutions
*All solutions compute both parts simultaneously unless noted otherwise.*

*Solutions are optimized for throughput, designed to handle continuous streaming input. Hardcaml designs are benchmarked against optimized CPU implementations courtesy of https://github.com/maneatingape/advent-of-code-rust*

*Python reference solutions are provided.*

### Day 1 - [Secret Entrance](https://adventofcode.com/2025/day/1)

The solution processes one dial instruction per cycle using combinational `divmod_100` logic to compute position wraps without iteration.

The dial has 100 positions, so computing `new_pos = (pos ± N) mod 100` and counting wraps requires division. Rather than sequential division, the design uses parallel comparators: a priority encoder finds the quotient by checking `x >= q*100` for q = 10 down to 1, while all 11 possible remainders are precomputed. A mux selects the correct remainder based on the quotient. This trades LUT area for single-cycle latency.

|  | [solution.ml](https://github.com/pserb/advent-of-fpga-2025/blob/main/day01/src/solution.ml) |
|--------|-----------|
| Slice LUTs | 140 (0.43%) |
| Slice Registers | 51 |
| Slices | 51 (0.63%) |
| Clock Period | 6.600 ns |
| Frequency | 151.52 MHz |
| Cycles / Instruction | 1 |
| Throughput | 151.52 M instr/s |
| Completion (4500 instr) | 29.70 μs |

| | [solution.ml](https://github.com/pserb/advent-of-fpga-2025/blob/main/day01/src/solution.ml) | [Target](https://github.com/maneatingape/advent-of-code-rust/blob/main/src/year2025/day01.rs) | vs Target |
|---|------|--------|-----------|
| Completion | 29.70 μs | 24 μs | 0.81 |

*Target: CPU benchmark (24 μs on Apple M2 Max). Ratio < 1 indicates slower than baseline.*
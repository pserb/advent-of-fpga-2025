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

## Getting Started
*This assumes you have setup your developer environment using Hardcaml with OxCaml and opam, with Jane Street extensions. Installation instructions are here: https://github.com/janestreet/hardcaml_template_project/tree/with-extensions*

Clone the repo, and run the following from the project **root**

Run the testbench for a specific day
```
dune test day01
```
Run all testbenches
```
dune runtest
```
Generate the RTL (verilog) for a specific day
```
dune exec lib/generate_rtl.exe day01 > day01.v
dune exec lib/generate_rtl.exe day02 > day02.v
...
```
Run the python reference solution for a specific day
```
cd day01/python/
uv run solution.py
```
If you haven't heard of `uv`... become familiar and start using it :) \
Absolutely the way to work with python: https://docs.astral.sh/uv/


## I/O
Problem inputs are converted to an int list of bytes, which are sent one byte per clock cycle. This is to keep focus on the solution-solving hardware. Optimally, instead packets of data would be sent once per cycle, each packet problem-specific. \
*e.g. for day 1, each packet would contain dial rotation (L50, R42, etc.)*
*Note: I/O is implemented under this "packet" assumption for some problems to highlight a particularly efficient solution*

Part 1 and 2 solutions are output.

## Solutions
*All solutions compute both parts simultaneously unless noted otherwise.*

*Solutions are optimized for throughput, designed to handle continuous streaming input. Hardcaml designs are benchmarked against optimized CPU implementations courtesy of https://github.com/maneatingape/advent-of-code-rust*

*Python reference solutions are provided.*

### Performance

| Day | Solution | FPGA (us) | CPU (us) | Ratio |
|----:|:---------|----------:|---------:|------:|
| 1 | [solution.ml](day01/src/solution.ml) | 29.70 | 24 | 0.81 |
| 2 | [solution.ml](day02/src/solution.ml) | 0.28 | 1 | 3.57 |
| 3 | [solution.ml](day03/src/solution.ml) | 242.42 | 21 | 0.09 |
| 4 | - | - | 177 | - |
| 5 | - | - | 20 | - |
| 6 | - | - | 20 | - |
| 7 | - | - | 5 | - |
| 8 | - | - | 527 | - |
| 9 | - | - | 40 | - |
| 10 | - | - | 194 | - |
| 11 | - | - | 75 | - |
| 12 | [solution.ml](day12/src/solution.ml) | 2.50 | 25 | 10.00 |
| **Total** | | **274.90** | **1129** | **-** |

### Day 1 - [Secret Entrance](https://adventofcode.com/2025/day/1) | [solution.ml](day01/src/solution.ml)

The solution processes one dial instruction per cycle using combinational `divmod_100` logic to compute position wraps without iteration.

The dial has 100 positions, so computing `new_pos = (pos ± N) mod 100` and counting wraps requires division. Rather than sequential division, the design uses parallel threshold counting: 10 comparators check `x >= 100`, `x >= 200`, ..., `x >= 1000` simultaneously, and a tree adder sums the results to get the quotient. All 11 possible remainders are precomputed in parallel, and a mux selects the correct one. This trades LUT area for single-cycle latency.

| Area (LUTs) | Latency (ns) | Freq (MHz) | Power (W) | Cycles/Op | Throughput (Op/s) | Completion (us) |
|------------:|-------------:|-----------:|----------:|----------:|------------------:|----------------:|
| 140 (0.43%) | 6.600 | 151.52 | - | 1 | 151.52M | 29.70 |

*Op = one dial instruction (e.g., R42)*

### Day 2 - [Gift Shop](https://adventofcode.com/2025/day/2) | [solution.ml](day02/src/solution.ml)

The key realization is that invalid IDs (numbers like 12341234) form arithmetic sequences. For 4-digit IDs with 2-digit patterns, 1212, 1313, 1414 are spaced exactly 101 apart (call 101 a "step"). This means we can sum all invalid IDs in a range using the triangular number formula rather than enumerating them.

There are 13 distinct pattern families: 5 for Part 1 (exact 2x repetition), 6 additional for Part 2 (3+ repetitions), and 2 overlap cases that get double-counted and must be subtracted. The design computes all 13 contributions in parallel, then combines them with tree adders for Part 1 and inclusion-exclusion arithmetic for Part 2.

Each family has a different step value (11, 101, 1001, etc.), and we need to divide by these to find how many invalid IDs land in a range. Instead of using a hardware divider, we precompute reciprocals: `x / step = (x * recip) >> 56` where `recip = ceil(2^56 / step)`. This turns division into a multiply and shift, fully pipelineable.

Each clock cycle, a single [low, high] range arrives. All 13 engines compute their contribution in parallel (the sum of invalid IDs from that pattern family within the range), tree adders combine the results, and the totals accumulate into running Part 1 and Part 2 sums. When the last range is processed, the answers are ready.

The tradeoff here is that single-cycle-per-range means long combinational paths, and parallelizing all 13 pattern engines with their reciprocal multipliers consumes 56.85% of available LUTs. But the result is 3.57x faster than the CPU baseline, validating the approach.

| Area (LUTs) | Latency (ns) | Freq (MHz) | Power (W) | Cycles/Op | Throughput (Op/s) | Completion (us) |
|------------:|-------------:|-----------:|----------:|----------:|------------------:|----------------:|
| 18,532 (56.85%) | 10.000 | 100.00 | 0.789 | 1 | 100M | 0.28 |

*Op = one [low, high] range from the input (e.g., 95-115)*

### Day 3 - [Lobby](https://adventofcode.com/2025/day/3) | [solution.ml](day03/src/solution.ml)

Each bank of 100 digits requires selecting exactly k digits (k=2 for Part 1, k=12 for Part 2) to form the largest possible number while maintaining left-to-right order. Greedy selection works because earlier digit positions have higher place value.

The solution uses a monotonic stack algorithm that processes digits in a single pass as they stream in. For each incoming digit, we pop elements from the stack that are smaller and can be safely replaced (given remaining digits), then push the current digit if the stack isn't full. Two parallel stacks run simultaneously: one for k=2, one for k=12.

All pop decisions can be computed in parallel. For each stack position, a comparator checks if that element is smaller than the incoming digit and if popping it leaves enough remaining digits to fill to k. A priority encoder finds the lowest valid pop point, and a barrel shifter updates the stack in one cycle.

When a newline arrives, each stack is converted to a number and accumulated into the running total. The design processes one byte per cycle with simple 8-bit streaming I/O.

| Area (LUTs) | Latency (ns) | Freq (MHz) | Power (W) | Cycles/Op | Throughput (Op/s) | Completion (us) |
|------------:|-------------:|-----------:|----------:|----------:|------------------:|----------------:|
| 474 (1.45%) | 12.000 | 83.33 | 0.142 | 101 | 825K | 242.42 |

*Op = one 100-digit bank*

### Day 12 - [Christmas Tree Farm](https://adventofcode.com/2025/day/12) | [solution.ml](day12/src/solution.ml)

*This problem has no Part 2*

We are trying to determine whether N presents (each constrained to fit in a 3×3 block) can fit into a defined WxH region. Turns out, this reduces to a simple area check: if `total_presents × 9 ≤ W × H`, they fit.

Each input line arrives as 32 bytes of ASCII (`"WxH: P0 P1 P2 P3 P4 P5"`). Since all dimensions and present counts are exactly 2 digits, byte positions are fixed at compile time. The parser extracts 8 two-digit numbers by subtracting `'0'` from each digit byte, multiplying the tens digit by 10, and adding.

The core algorithm is three operations: sum 6 present counts, multiply dimensions for area, compare. A tree adder sums the presents, a single multiplier computes area, and a comparator decides fit. When a region fits, a counter increments. After 1000 lines, the count is the answer.

| Area (LUTs) | Latency (ns) | Freq (MHz) | Power (W) | Cycles/Op | Throughput (Op/s) | Completion (us) |
|------------:|-------------:|-----------:|----------:|----------:|------------------:|----------------:|
| 208 (0.64%) | 2.500 | 400.00 | 0.100 | 1 | 400M | 2.50 |

*Op = one region line (e.g., "43x45: 35 25 41 42 28 38")*

Note: At 32 bytes of I/O per cycle and 400 MHz, an input interface needs to sustain 12.8 GB/s of throughput. This can be satisfied through 100G/200G/400G ethernet networking, DDR4/DDR5 SDRAM (prefilled), or PCIe 4.0x16 or 5.0x8/x16 connected to a host machine generating the input stream.


## Project Structure
All days follow the same structure with a python reference solution, hardcaml src and a testbench (verifying puzzle solving correctness)
```
$ tree day01/

day01
├── python
│   ├── pyproject.toml
│   ├── solution.py
│   └── uv.lock
├── src
│   ├── dune
│   ├── generate_rtl.ml
│   ├── optimization_ideas.md
│   └── solution.ml
└── test
    ├── dune
    └── testbench.ml
```

`inputs/` contains txt file puzzle inputs for each day \
`lib/` contains ocaml helper code for testbench simulation

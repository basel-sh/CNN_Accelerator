# Verification Results — Phase 9 (Simulation)

Status as of this run: **Phases 2-9 implemented and passing.** Phases
10-14 (optimization, Vivado synthesis/timing/power, final report) are still
pending and require the Vivado GUI/toolchain — see "What's left" below.
Naming: all signals below use the `First_Second` convention (root
`README.md` §6) — this doc was refreshed after that rename; the RTL logic
itself did not change and 900/900 outputs are still bit-exact.

## What was implemented and run

- **Phase 2 (Python Golden Model):** `convolution.py`, `golden_model.py`,
  `image_loader.py`, `image_generator.py`, `utilities.py` are fully
  implemented (unsigned pixel / signed 8-bit kernel / signed 20-bit
  accumulator, valid convolution, stride 1, optional ReLU). Verified against
  hand-computed values.
- **Phases 3–8 (RTL):** `ram.v`, `fifo.v`, `image_memory.v`,
  `kernel_memory.v`, `line_buffer.v`, `window_generator.v`, `mac.v`,
  `controller.v`, `output_buffer.v`, `top.v` are fully implemented (see
  `Architecture.md` for the finalized pipeline-latency design).
- **Phase 9 (Simulation):** Since Vivado isn't available in this automated
  environment, RTL correctness was verified by installing **Icarus Verilog**
  and running the testbenches directly:
  - `tb_mac.v` — 3/3 hand-computed vectors passed.
  - `tb_controller.v` — address sequencing (row-major, no gaps) and
    valid-window count both verified exact on an 8x8/K=3 case.
  - `tb_top.v` — full system test, 32x32 image, 3x3 kernel, run twice:
    1. Edge-detect kernel, ReLU off — **900/900 outputs bit-exact** vs.
       the Python golden model.
    2. Random signed kernel, ReLU on — **900/900 outputs bit-exact**.

  `Python/verify.py` performs the automated comparison and exits 0 (PASS) /
  1 (FAIL), suitable for CI.

## Bugs found and fixed during this pass

1. **`line_buffer.v` initial design** used a shared read/write address trick
   on `ram.v` (a common BRAM line-buffer technique) that Icarus Verilog
   simulated inconsistently for same-cycle same-address access. Replaced
   with a plain flip-flop shift-register delay chain — functionally
   identical, unambiguous in any simulator/synthesizer. Re-introducing a
   BRAM-backed version (lower FF count) is a tracked Phase 10 item, using a
   true dual-port RAM with distinct, never-simultaneously-equal addresses.
2. **`tb_top.v` preload loops** changed stimulus signals (`Img_We`,
   `Img_Waddr`, ...) using blocking assignments immediately after
   `@(posedge Clk)` — a classic testbench/DUT same-edge race, non-
   deterministically dropping about half the writes. Fixed by driving all
   stimulus changes on `@(negedge Clk)`, safely away from the DUT's own
   `@(posedge Clk)` logic.

## What's left (needs the Vivado GUI, on your machine)

- Phase 10 — Optimization (pipeline for timing/resources, BRAM line buffer).
- Phase 11 — Synthesis (`Scripts/build.tcl` + `Scripts/synthesize.tcl`).
- Phase 12 — Timing closure (`Vivado/constraints.xdc`).
- Phase 13 — Power analysis.
- Phase 14 — Final report / FoM.

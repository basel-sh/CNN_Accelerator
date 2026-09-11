# Verification Results

## What's verified

- **Golden model:** `convolution.py`, `golden_model.py`, `image_loader.py`,
  `image_generator.py`, `utilities.py` — unsigned pixel / signed 8-bit kernel /
  signed 20-bit accumulator, valid convolution, stride 1, optional ReLU.
- **RTL:** `kernel_memory.v`, `image_memory_2px.v`, `line_buffer_2px.v`,
  `window_generator_2px.v`, `mac_pair.v`, `controller_2px.v`, `top_2px.v`.
- **System-level (`tb_top_2px.v`, Vivado XSim, 32x32 image, 3x3 kernel):**
  the vertical-Sobel demo kernel (`edge_3x3.mem`), ReLU off —
  **900/900 outputs bit-exact** vs. the Python golden model. This is the
  result recorded in `Documentation/Aggressive2px.md` and used for every
  synthesis run in `Reports/`.

`Python/verify.py` performs the automated comparison and exits 0 (PASS) /
1 (FAIL), suitable for CI.

## What's NOT yet verified for the current design

Everything above uses the same one image/kernel pair. Two cases are written
into the repo but not yet run through the current (`top_2px.v`) design:

- **`Images/kernels/random_3x3_test2.mem`** — a second, unstructured signed
  kernel. (The old baseline was tested against this in Icarus before it was
  removed; the current design has not.)
- **ReLU on.** `tb_top_2px.v` supports it via `-testplusarg RELU=1`, but it's
  never actually been run that way in Vivado.

Neither testbench takes the kernel file as a runtime parameter — both
hardcode `$readmemh("Images/kernels/edge_3x3.mem", ...)` — so running the
second kernel means temporarily editing that one line in
`Testbench/tb_top_2px.v`, re-simulating, and reverting it. Exact commands are
in the root `README.md` command reference, phase 15 of
`Documentation/DevelopmentRoadmap.md` tracks doing this before the report is
finalized.

## Bugs found and fixed along the way

Carried over from the original (now-removed) baseline's development, since
the fixes apply to shared modules (`kernel_memory.v`) or shaped the current
design's line-buffer approach:

1. An early line-buffer design used a shared read/write address trick on a
   generic RAM primitive that simulated inconsistently for same-cycle
   same-address access in Icarus Verilog. `line_buffer_2px.v` uses a plain
   flip-flop shift-register delay chain instead — functionally unambiguous in
   any simulator/synthesizer, at the cost of more FFs than a BRAM-backed
   version would use.
2. An early testbench preload loop changed stimulus signals using blocking
   assignments immediately after `@(posedge Clk)` — a same-edge race with the
   DUT's own posedge logic that non-deterministically dropped about half the
   writes. `tb_top_2px.v` drives all stimulus changes on `@(negedge Clk)`.

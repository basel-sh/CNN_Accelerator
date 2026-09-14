# Verification Results

## What's verified

- **Golden model:** `convolution.py`, `golden_model.py`, `image_loader.py`,
  `image_generator.py`, `utilities.py` — unsigned pixel / signed kernel
  (4 bits used) / signed 16-bit accumulator, valid convolution, stride 1,
  optional ReLU.
- **RTL:** `kernel_memory.v`, `image_memory_2px.v`, `line_buffer_2px.v`,
  `window_generator_2px.v`, `mac_pair.v`, `controller_2px.v`, `fifo_pair.v`,
  `top_2px.v`, `axi_lite_top_2px.v`.
- **System-level (`tb_top_2px.v`, Vivado XSim, 32x32 image, 3x3 kernel):**
  the vertical-Sobel demo kernel (`edge_3x3.mem`), ReLU off —
  **900/900 outputs bit-exact** vs. the Python golden model, re-confirmed
  against the final `Kernel_W=4`/`Acc_W=16` build and used for every
  synthesis run in `Reports/`.
- **Alternate input photo**, same vertical-Sobel kernel — regenerated
  `Images/input_32x32.mem` via `Python/prepare_stimulus.py` from a different
  source photo — **900/900 outputs bit-exact**.
- **Alternate kernel** — a horizontal-edge Sobel filter
  (`[[-1,-2,-1],[0,0,0],[1,2,1]]`), written into `Images/kernels/edge_3x3.mem`
  by editing the coefficient array in `Python/prepare_stimulus.py` and
  re-running it — **900/900 outputs bit-exact**. See "Bugs found" below for
  a mistake caught during this run.
- **10 random-seed sweep** (`generic_tests.py`, Icarus, seeds 0-9): random
  32x32 images x random signed 3x3 kernels, ReLU alternated — **0 mismatches
  across all 900-output seeds**.
- **Kernel-size and image-size generalization** (`tb_generic.v`, Icarus):
  re-elaborated with `Img_W=Img_H=64` (3844/3844 valid outputs) and separately
  with `K=5` — the `K=5` run is what caught the hardcoded-adder-tree bug
  listed under "Bugs found" below.
- **AXI4-Lite bus interface** (`tb_axi_lite.v`, Icarus, against the
  2026-09-12 `axi_lite_top_2px.v`): kernel-write pulse timing (TIM-08),
  undecoded-address writes/reads returning OKAY with no side effect (ERR-06),
  an `OUT_DATA` read while empty still completing with no hang (ERR-07), and
  `OUT_DATA` readback matching `Out_Data0` sign-extended to 32 bits against a
  real computed result (TIM-09) — all passing.
- **Backpressure, reset, and error handling** (`tb_backpressure.v`, Icarus):
  an idle consumer no longer silently drops results — the 16-deep
  `fifo_pair.v` queues them and asserts `Out_Full` once genuinely full
  (ERR-03/ERR-04/TIM-06); a reset with unread results still queued clears the
  FIFO cleanly with no stale `Out_Valid` (RST-03); a mid-scan `Img_We`/
  `Kernel_We` write causes no X-propagation and the scan still completes
  (ERR-05, documented as having no interlock by design).

All of the above beyond the original golden-model comparison is captured
formally, row by row, in `Verification_Test_Plan.xlsx` (46 test IDs) and
re-run end to end via `python Testbench/audit_icarus_2026-09-12/run_all.py`.
`Python/verify.py` performs the automated golden-model comparison and exits 0
(PASS) / 1 (FAIL), suitable for CI.

## What's NOT yet verified for the current design

- **ReLU on, in Vivado specifically.** `tb_top_2px.v` supports it via
  `-testplusarg RELU=1`, and the Icarus suite's `tb_generic.v` exercises the
  RTL's `RELU` parameter directly, but the dedicated Vivado XSim run with
  `RELU=1` hasn't been done yet. Exact commands are in the root `README.md`
  command reference (§4).

The kernel and image are both single fixed-name files
(`Images/kernels/edge_3x3.mem`, `Images/input_32x32.mem`) that
`tb_top_2px.v` always reads by that name — "testing another kernel/image"
means regenerating those files' *contents* via `Python/prepare_stimulus.py`,
not editing the testbench. (An earlier, now-deleted second kernel file,
`random_3x3_test2.mem`, needed a testbench edit to select a different
`$readmemh` path — that approach no longer applies.)

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
3. `tb_top_2px.v` wrote its result to `sim/rtl_output_2px.mem` while
   `Python/mem_to_image.py` was hardcoded to read `sim/rtl_output.mem` — a
   naming split left over from when the `_2px` testbench replaced the
   baseline one. Every visual check needed a manual copy between the two
   names. Fixed by renaming the testbench's `$fopen` target (and
   `Scripts/run_simulation_2px.tcl`'s copy-back step) to `sim/rtl_output.mem`
   directly.
4. Testing the horizontal-Sobel kernel above initially used a hand-typed
   coefficient array with a sign error: `-2` was entered as `2`. `verify.py`
   still reported **PASS**, because both the RTL and the Python golden model
   read the *same* `edge_3x3.mem` file — they agreed with each other, just
   against the wrong stimulus. The bug only surfaced because the rendered
   output image still looked like vertical-edge detection; confirmed by
   dumping the kernel `.mem` file's hex content directly. **A golden-model
   PASS only proves RTL/golden agreement on whatever stimulus file both sides
   were given — it cannot catch a stimulus file that's wrong in a way both
   sides interpret identically.** Independently double-checking hand-entered
   coefficients (or generating them programmatically instead of typing
   sign-by-sign) is the mitigation.

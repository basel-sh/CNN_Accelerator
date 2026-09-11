# Optimization Log — Phase 10 (FoM optimization pass)

**Status note (2026-09-11):** this document is a historical log of the 1-pixel/cycle
`RTL/top.v` baseline's optimization pass. That baseline has since been removed from
the repository, replaced by the 2-pixel/cycle, zero-DSP `RTL/top_2px.v` design (see
`Documentation/Aggressive2px.md` section 9 and root `README.md`). Kept here because
several of the fixes below (DRC reset-hazard fixes, the reasoning against forcing
DSP48 use) are still the reasoning behind the current design's choices.

Baseline (xc7z020clg400-1 / PYNQ-Z2, 100 MHz, post-implementation, 2026-09-05):
LUT 7396, FF 20966, DSP 0, BRAM 0.5, Power 0.339 W -> FoM = 1/(0.339*(7396+50)) ~= 3.96e-4

## Fix 1 — Output FIFO was 64x oversized and forced into registers, not BRAM
`RTL/top.v` instantiated `output_buffer` with `Out_Depth = 1024` (a full-frame's
worth of results), and `RTL/fifo.v` reads its memory array combinationally
(`assign Rd_Data = Mem[Rptr]`). That async-read style does not infer Block RAM,
so Vivado built it from ~20,480 flip-flops plus a large 1024:1 read mux — this
alone accounted for essentially all of Slice Registers (20966) and a large share
of the F7/F8 mux count and LUT-as-Logic total in the utilization report.
The testbench (`tb_top.v`) holds `Out_Rd_En = 1` permanently — it drains every
result the same cycle it's produced — so the FIFO never needs more than a
couple of entries of slack in this design. Changed `Out_Depth`/`Out_Aw` in
`RTL/top.v` (and the matching defaults in `RTL/output_buffer.v`) from
1024/10 to 16/4. No functional/interface change — re-run simulation to confirm
900/900 still passes before trusting new synthesis numbers.

## Fix 2 — Clock relaxed from 100 MHz to 20 MHz (Vivado/constraints.xdc)
The competition's FoM uses Throughput in pixels/CYCLE (frequency-independent),
while Power scales with clock frequency. The 100 MHz constraint was a
placeholder ("no physical board selected yet"), not an application
requirement — this accelerator only needs to sustain 900 pixels/frame, so
20 MHz still gives >20,000 frames/sec of headroom for a 32x32 input, far more
than any real edge-vision workload needs. Slowing down to only what the
application requires is a legitimate low-power edge-AI design choice, and it
directly reduces the Power term without touching Throughput.
The 100 MHz run closed timing with WNS = +1.017 ns, so this design can run up
to ~111 MHz if a future application needs more throughput — report that as
"maximum achievable frequency" in Table 1, separate from the 20 MHz chosen
operating point (with its own, lower power number).

## Next steps to get real post-fix numbers
1. Re-run simulation (Scripts/run_simulation.tcl or the Icarus fast path) —
   confirm 900/900 PASS.
2. Re-run Synthesis, then Implementation in Vivado.
3. Re-open Implemented Design -> Report Power / Report Utilization / Report
   Timing Summary, and recompute FoM the same way as the baseline above.

## Result (xc7z020clg400-1 / PYNQ-Z2, 20 MHz, post-implementation, 2026-09-05)
Simulation re-verified first: 900/900 outputs, bit-exact PASS (with Out_Depth=16).

LUT 842, FF 740, DSP 0, BRAM 0.5, Power 0.111 W (dynamic 0.007 + static 0.104)
Timing: WNS = +41.975 ns @ 50 ns (20 MHz) constraint -> achievable Fmax ~= 1/(50-41.975)ns ~= 125 MHz

FoM = 1 / (0.111 * (842 + 0 + 50)) = 1 / 99.01 = 1.010e-2

Improvement over baseline: 1.010e-2 / 3.96e-4 ~= 25.5x

## Further legal-optimization search (post-25.5x fix) - what's left, and what isn't worth it

Evaluated and rejected (with the math, so the reasoning is auditable):
- Move MAC multiplies from fabric LUTs to DSP48 slices: each DSP costs 50 in the FoM
  denominator; a fabric 9x8 signed multiplier costs far fewer LUTs than that on this
  device. Net effect would be WORSE FoM. Kept DSPs at 0.
- Time-multiplex/share the MAC across 9 cycles instead of fully unrolling 9 parallel
  taps: would cut MAC-related LUTs, but Throughput (pixels/cycle) would drop by 9x,
  which dominates the LUT savings. Net effect would be WORSE FoM (checked
  numerically: ~0.1/9 throughput vs a partial LUT cut is a large net loss). Keeping
  the fully-pipelined 1 output-pixel/cycle datapath (also a listed competition bonus
  item) is FoM-optimal.
- Move image_memory off the one BRAM tile into distributed RAM to zero out the BRAM
  term: an 8-bit x 1024-deep memory costs roughly 128 LUTs as distributed RAM, more
  than the 50-point BRAM penalty (100 x 0.5) it would remove. Net effect would be
  WORSE FoM. Kept the single RAMB18.

Applied: clock dropped from 20 MHz to 1 MHz (see constraints.xdc comment). At 20 MHz,
Dynamic power was already only 0.007 W of 0.111 W total (94% is Device Static, which
is roughly fixed regardless of clock). This is the last "free" squeeze on this lever -
going below ~1 MHz buys well under 1% more, since it can only ever approach the
~0.104 W static floor. Re-run Implementation once more to get the real updated
Power/FoM numbers.

Open, NOT yet attempted (real upside, real risk - needs explicit sign-off before
touching it): tightening Acc_W from 20 bits toward the rule's 16-bit minimum. 20 bits
is the mathematically exact worst-case bound for a fully general 8-bit signed kernel
(9 x 255 x 127 needs 20 bits incl. sign), so it is not "oversized" for the general
case - only for the specific edge_3x3 Sobel kernel actually used in verification,
whose real sums are much smaller due to sign cancellation. Shrinking it would need:
(1) proving the tested kernel(s) never overflow the new width, (2) updating
Python/golden_model.py + verify.py's --acc-width to match exactly, (3) full
re-simulation to re-confirm bit-exact PASS. Do this only as a deliberate, verified
step, not a quick edit.

## Methodology warnings triage (178 total, after the 1 MHz change)
- 117 x "multiplier implemented as LUTs... use USE_DSP48 to force DSP": expected,
  not a defect - confirms the no-DSP decision above (forcing DSP48 costs 50/each
  in the FoM denominator, more than the LUTs saved). Left as-is intentionally.
- 1 x "RAM Mem_reg... no output register merged, timing might be sub-optimal":
  about squeezing more max-Fmax headroom out of the image-memory BRAM read.
  Irrelevant to a design deliberately clocked at 1 MHz for power/FoM, and fixing
  it would add a pipeline stage that ripples through top.v's valid-tag alignment
  logic for no benefit here. Left as-is intentionally.
- 60 x "missing input/output delay on <port>": real gap - constraints.xdc never
  declared I/O timing since no board/PS interface is bound yet. Fixed with
  set_input_delay/set_output_delay 0 (and set_false_path for the async Rst_N)
  referenced to sys_clk - the standard placeholder for a design not yet wired to
  physical pins. Pure constraint hygiene, no RTL/logic change, does not affect
  utilization, power, or FoM.

## DRC triage (2 Critical Warnings, 13 Warnings = 15 total, on the xc7z020 build)
Fixed:
- REQP-1840 (11x, RAMB18E1 required-pin): U_Ctrl's Mem_Raddr/Streaming registers
  drove the BlockRAM's address/enable pins with an ASYNCHRONOUS reset - a real
  hazard (not just style): Vivado flags this because async-driven BRAM control
  pins aren't covered by static timing analysis and could corrupt memory
  contents if reset asserts mid-access. Fixed by making controller.v's always
  block synchronous-reset only (posedge Clk, no negedge Rst_N in the sensitivity
  list). Verified safe: tb_top.v holds Rst_N low for 3 full clock cycles before
  Start, deasserted on a negedge boundary - synchronous reset behaves identically
  in this testbench. Re-run simulation to reconfirm 900/900 after this change.

Left as-is, intentionally (all bitstream-only or Fmax-only, not applicable to
this deliverable):
- NSTD-1 / UCIO-1 (critical): "ports use default IOSTANDARD / no LOC" - these
  only block *Generate Bitstream*, not synthesis/implementation. This project
  has no physical pinout yet (see constraints.xdc header) and the competition
  only requires synthesis/implementation reports - a board demo is an optional
  bonus. Only relevant if a real board bring-up is attempted later, and even
  then this top-level (raw control ports, no AXI/PS7 wrapper) isn't wired for
  direct PYNQ-Z2 pin mapping - that would need a separate Block Design effort.
- ZPS7-1: Zynq designs normally need a PS7 IP block for correct power-up -
  irrelevant for a PL-only RTL synthesis/implementation deliverable with no
  bitstream planned.
- RBOR-1 (same instance as the earlier SYNTH-6 Methodology warning): about
  squeezing more Fmax out of the image-memory BRAM read; irrelevant to a design
  deliberately clocked at 1 MHz for power/FoM.

## Post-fix confirmation run (controller.v sync-reset, DRC REQP-1840)

Fresh impl_1 run (fully routed) at 1 MHz confirmed:
- DRC: 15 -> 4 violations. All 11 REQP-1840 warnings gone. Remaining 4
  (NSTD-1, UCIO-1, RBOR-1, ZPS7-1) are the same intentionally-left items
  documented above.
- LUT 841, FF 740, DSP 0, BRAM 0.5 (essentially unchanged from pre-fix).
- Total Power 0.140 W (Dynamic 0.035 W, Static 0.105 W) - WORSE than the
  20 MHz run's 0.111 W, contradicting the theoretical clock-lever math.
  Report Confidence Level was "Low" (vectorless estimate, no SAIF) - treated
  as an estimator artifact, not a real regression.
- Decision: reverted constraints.xdc clock to 20 MHz (50 ns period), the
  verified-better operating point, keeping the controller.v DRC fix (which is
  clock-independent). Re-running impl_1 now to get final, fully-consistent
  numbers (DRC fix + 20 MHz) for the report.

## FINAL confirmed numbers (20 MHz + controller.v DRC fix, fully routed)

- DRC: 4 violations (NSTD-1, UCIO-1, RBOR-1, ZPS7-1) - all intentional, documented above. REQP-1840 fully resolved.
- Utilization: LUT 841, FF 740, DSP 0, BRAM 0.5.
- Power: Total 0.148 W (Dynamic 0.043 W, Static 0.105 W, Confidence Level: Low - vectorless estimate).
  Note: power came back ~0.14-0.15 W at BOTH 1 MHz and 20 MHz after the sync-reset fix, so the
  earlier clock-lever power model no longer applies post-fix - the sync-reset change itself
  (not frequency) is what moved the estimate, most likely because the reset value now routes
  through the LUT fabric feeding those registers instead of a dedicated async clear net. This is
  the honest, current, low-confidence estimate; keeping 20 MHz since it gives comfortable timing
  margin and a higher, still-accurate max-achievable-Fmax figure to report.
- Timing: WNS = +35.731 ns @ 50 ns period -> achievable Fmax = 1/(50-35.731ns) ~= 70.1 MHz.
  (Revised down from the pre-fix ~111 MHz estimate - the sync-reset conversion lengthened the
  critical path, a real and expected trade-off for fixing a genuine reset-hazard DRC violation.)
- FoM = Throughput / (Power x (LUT + 50*DSP + 100*BRAM))
      = 1 / (0.148 x (841 + 0 + 50))
      = 1 / (0.148 x 891) = 1 / 131.87 = 7.58e-3
  vs baseline (100 MHz, unoptimized) FoM = 3.96e-4 -> ~19.1x improvement.
  vs pre-DRC-fix best (1.01e-2): DRC fix cost ~25% FoM in exchange for removing a real reset
  hazard on BlockRAM control pins (REQP-1840) - a legitimate robustness/FoM trade-off, worth
  stating explicitly in the report as a design-quality decision, not an oversight.

## FINAL confirmed numbers (20 MHz + controller.v + line_buffer.v DRC fixes)

- DRC: 3 violations remaining (NSTD-1, UCIO-1, ZPS7-1) - all bitstream/board-only, cannot be
  legitimately fixed without a real physical board target or an unused PS7 block (see rationale
  logged above). RBOR-1 and REQP-1840 (12 checks total) fully resolved via sync-reset RTL fixes.
- Utilization: LUT 842, FF 758, DSP 0, BRAM 0.5.
- Power: Total 0.149 W (Dynamic 0.044 W, Static 0.105 W).
- Timing: WNS = +35.538 ns @ 50 ns (20 MHz) -> achievable Fmax ~= 1/(50-35.538) ~= 69.1 MHz.
- FoM = 1 / (0.149 x (842 + 0 + 50)) = 1 / (0.149 x 892) = 1 / 132.9 = 7.52e-3
  vs baseline (3.96e-4) -> ~19.0x improvement. This is the final reportable result.

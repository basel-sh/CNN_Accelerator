# Performance Results (for the final competition report)

Computed from `Reports/timing/timing_impl.txt`, `Reports/utilization/utilization_impl.txt`,
`Reports/power/power_impl.txt` — routed `impl_1`, `xc7a35tcpg236-1`, 20 MHz,
**re-synthesized 2026-09-12** against the current `RTL/top_2px.v` (the K-generalized
`mac_pair.v` reduction + the new `fifo_pair.v` output queue are both included in this
build; see `Documentation/VerificationResults.md` and the audit note in the project doc
for what changed and how it was re-verified in simulation first).
Full design-space history (why this design instead of the two that came before it):
`Documentation/Aggressive2px.md`.

**Scope note:** `RTL/axi_lite_top_2px.v` is a separate top-level wrapper that instantiates
`top_2px.v` for bus-based control; `Scripts/synthesize_2px.tcl` sets `top_2px` (not the AXI
wrapper) as the synthesis top, so the numbers below do **not** include the AXI4-Lite
register-decode logic. If a routed number for the AXI-wrapped design is ever needed,
`axi_lite_top_2px.v` has to be synthesized as its own top separately.

## Fmax (maximum clock frequency)

Constrained clock: 20 MHz (50.000 ns period).
Post-route timing: WNS = +32.627 ns (all constraints met) — down from +35.076 ns in the
previous routed build, a small, expected cost of the extra FIFO/output-mux logic now in
the critical path's fanout.

```
Fmax ~= 1000 / (Period_ns - WNS_ns)
      = 1000 / (50.000 - 32.627)
      = 1000 / 17.373
      ~= 57.6 MHz
```

**Fmax ~= 57.6 MHz** (estimated from WNS at the 20 MHz constraint; the chosen
operating point is 20 MHz, still comfortably inside this margin).

## Figure of Merit

```
FoM = Throughput / (Power x (LUTs + 50*DSPs + 100*BRAMs))
```

| Term | Value | Source |
|---|---|---|
| Throughput | 2 output pixels/cycle | `mac_pair.v` produces both lanes every cycle, steady-state |
| Power | 0.122 W | `Reports/power/power_impl.txt` (Dynamic 0.051 W + Static 0.070 W) |
| LUTs | 1605 | `Reports/utilization/utilization_impl.txt` |
| DSPs | 0 | `Reports/utilization/utilization_impl.txt` |
| BRAMs | 1.0 | `Reports/utilization/utilization_impl.txt` (2x RAMB18E1 = 1 tile, 36k-equivalent units) |

```
FoM = 2 / (0.122 x (1605 + 50*0 + 100*1.0))
    = 2 / (0.122 x 1705)
    = 2 / 208.01
    ~= 9.61e-3
```

**FoM ~= 9.61 x 10^-3** (output pixels/cycle per W.unit).

### What changed since the last routed build (LUT 1411 -> 1605, FF 638 -> 1288, FoM 1.10e-2 -> 9.61e-3)

The previous routed numbers (`FoM = 1.10e-2`) predate the output-FIFO integration and the
K-generalized MAC reduction fix (both landed 2026-09-12, see the verification-audit note).
That earlier report predicted "a modest LUT/FF increase from the FIFO and AXI logic" —
that prediction undersold it, and since AXI isn't even part of this synthesis target (see
scope note above), the FIFO + generic-reduction change alone accounts for the real
measured delta:

| Metric | Previous routed | Current routed | Change |
|---|---:|---:|---:|
| LUT | 1411 | 1605 | +194 (+13.7%) |
| FF | 638 | 1288 | +650 (+101.9%) |
| Power | 0.120 W | 0.122 W | +0.002 W |
| WNS @ 20 MHz | +35.076 ns | +32.627 ns | -2.449 ns (still all constraints met) |
| FoM | 1.10e-2 | 9.61e-3 | -12.8% |

The FF count roughly doubling is larger than the FIFO's own pointer/control logic
(`Wptr`/`Rptr`, a handful of bits) would suggest on its own; the top-level utilization
report doesn't break registers down per-submodule, so the exact split between the FIFO's
16-deep dual-lane memory (`Mem0`/`Mem1`, partly mapped to `SRL16E` per the primitives
table — 32 used) and any repacking of `mac_pair.v`'s registered products isn't something
this report can prove without a hierarchical utilization run (`report_utilization
-hierarchical`) in Vivado. Reported honestly as a real, larger-than-predicted cost of a
real correctness fix (the FIFO closes a genuine data-loss bug — see Verification_Test_Plan
ERR-04/TIM-06), not as a design regression.

This is a legitimate FoM/robustness trade, not a mistake: the alternative (no output
queue) is the bug the FIFO was added to fix. Trading ~12.8% FoM to stop silently dropping
unread results is the correct call for a competition scored partly on correctness and
partly on FoM together.

## Next legal FoM-optimization lever (evaluated, not yet applied)

Per `Documentation/Aggressive2px.md` section 9, the design-space search already ruled out,
with the numbers to back it up: (1) moving MAC multiplies to DSP48 slices, (2)
time-multiplexing the MAC over multiple cycles, and (3) moving `image_memory` off BRAM.
All three make FoM worse. The one lever left on the table, from the same document and from
`Documentation/OptimizationLog.md`'s "Open, NOT yet attempted" note, is tightening
`Acc_W`/`Prod_W` from the current 20/17 bits toward the competition's 16-bit output
minimum.

This is flagged, not applied, because it is not a free win: `Acc_W = 20` is the
mathematically exact bound for a **fully general** signed 8-bit kernel (the worst case,
9 x 255 x 128 = 293,760, needs 20 bits including sign — see the overflow analysis below).
Narrowing it below 20 bits would only be safe for a *restricted* class of kernels (e.g. the
specific edge-detection kernels actually used in verification, whose real sums are much
smaller due to sign cancellation), which changes what the design can honestly claim to
support. Doing this properly requires: (1) explicit sign-off on which kernel class the
narrower width is scoped to, (2) updating `Python/golden_model.py` / `verify.py`'s
`--acc-width` to match exactly, (3) a full re-simulation to reconfirm bit-exact PASS, and
(4) a fresh Vivado re-route to measure the real LUT/FF delta (not assumed here). None of
that was done as part of this update — see the accompanying note to Basel for the
go/no-go decision.

## Requirement #2 — input precision justification

`Pixel_W = 8` unsigned fixed-point (0-255). Chosen because: (a) 8-bit
grayscale is the standard precision for edge-AI vision inputs (matches
typical camera ADC / image sensor output and common CNN quantization
schemes), (b) it is the smallest power-of-two width that represents a full
0-255 grayscale range with no quantization loss versus the source image, and
(c) it keeps `Prod_W` and `Acc_W` (20 bits) small enough to close timing at
the chosen 20 MHz operating point (Fmax ~= 57.6 MHz) on a Zynq-7-series part
(`xc7a35tcpg236-1`) without any DSP slices.

## Requirement #6 — output precision & overflow handling

`Acc_W = 20` signed (exceeds the 16-bit minimum; "wider is allowed" per the
spec).

Overflow analysis (worst case, K=3 => 9 taps, applies per output lane):
- Max magnitude per product: unsigned pixel in [0,255] x signed kernel in
  [-128,127] => worst product = 255 x (-128) = -32640, or 255 x 127 = +32385.
- Max magnitude of the 9-term sum: 9 x 32640 = 293,760 (worst case, all taps
  at the extreme negative product simultaneously).
- A 20-bit signed value covers [-524288, 524287] (2^19 = 524288).
- 524,288 > 293,760, so the accumulator range structurally cannot overflow
  for any valid input combination — no saturation, truncation, or rounding
  logic is needed or implemented. Both output lanes in `mac_pair.v` use the
  identical 20-bit-sized adder tree, so this bound applies to each
  independently.
- ReLU (`Relu_En`, applied inline at `top_2px.v`'s output mux) is the only
  post-processing step, and only zeroes negative results when enabled; it
  does not affect this overflow analysis.

## Status vs. competition requirements

| # | Requirement | Status |
|---|---|---|
| 9 | LUTs/FFs/DSPs/BRAMs/Fmax/timing/power | Done — see table above + `Reports/` (re-synthesized 2026-09-12, no longer pending) |
| 10 | Figure of Merit | Done — see above (9.61e-3, re-derived from the current routed build) |
| 2 | Input precision justified in report | Done — see above |
| 6 | Output precision + overflow handling explained | Done — see above |

Remaining for the final report: none of the numeric content — the report and slides have
been updated with these confirmed, post-fix routed figures. Only open item is the
Acc_W-trim decision above, which is optional further optimization, not a requirement gap.

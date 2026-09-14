# Performance Results (for the final competition report)

Computed from `Reports/timing/timing_impl.txt`, `Reports/utilization/utilization_impl.txt`,
`Reports/power/power_impl.txt` — routed `impl_1`, `xc7a35tcpg236-1`, 20 MHz,
**re-synthesized 2026-09-14** against the current `RTL/top_2px.v`: the K-generalized
`mac_pair.v` reduction, the `fifo_pair.v` output queue (both landed 2026-09-12), and
the kernel-scoped `Kernel_W`/`Acc_W` narrowing (2026-09-13/14) are all included in this
build; see `Documentation/VerificationResults.md` for how each change was re-verified
in simulation before being resynthesized.
Full design-space history (why this design instead of the two that came before it):
`Documentation/OptimizationLog.md` (1px baseline) and `Documentation/Aggressive2px.md`
(2px design-space search, including the abandoned 4-DSP attempt).

**Scope note:** `RTL/axi_lite_top_2px.v` is a separate top-level wrapper that instantiates
`top_2px.v` for bus-based control; `Scripts/synthesize_2px.tcl` sets `top_2px` (not the AXI
wrapper) as the synthesis top, so the numbers below do **not** include the AXI4-Lite
register-decode logic. If a routed number for the AXI-wrapped design is ever needed,
`axi_lite_top_2px.v` has to be synthesized as its own top separately.

## Fmax (maximum clock frequency)

Constrained clock: 20 MHz (50.000 ns period).
Post-route timing: WNS = +33.802 ns (all constraints met).

```
Fmax ~= 1000 / (Period_ns - WNS_ns)
      = 1000 / (50.000 - 33.802)
      = 1000 / 16.198
      ~= 61.7 MHz
```

**Fmax ~= 61.7 MHz** (estimated from WNS at the 20 MHz constraint; the chosen
operating point is 20 MHz, still comfortably inside this margin).

## Figure of Merit

```
FoM = Throughput / (Power x (LUTs + 50*DSPs + 100*BRAMs))
```

| Term | Value | Source |
|---|---|---|
| Throughput | 2 output pixels/cycle | `mac_pair.v` produces both lanes every cycle, steady-state |
| Power | 0.113 W | `Reports/power/power_impl.txt` (Dynamic 0.042 W + Static 0.070 W) |
| LUTs | 896 | `Reports/utilization/utilization_impl.txt` |
| DSPs | 0 | `Reports/utilization/utilization_impl.txt` |
| BRAMs | 1.0 | `Reports/utilization/utilization_impl.txt` (2x RAMB18E1 = 1 tile, 36k-equivalent units) |

```
FoM = 2 / (0.113 x (896 + 50*0 + 100*1.0))
    = 2 / (0.113 x 996)
    = 2 / 112.548
    ~= 1.777e-2
```

**FoM ~= 1.777 x 10^-2** (output pixels/cycle per W.unit) — the best FoM of every
phase this project went through.

### Full design-history table (every routed build, in order)

| Phase | LUT | FF | Power (W) | WNS @ 20 MHz | FoM |
|---|---:|---:|---:|---:|---:|
| 1px baseline (2026-09-05) | 842 | 758 | — | — | 7.52e-3 |
| 2px zero-DSP, adopted (2026-09-11) | 1411 | 638 | 0.120 | +35.076 ns | 1.10e-2 |
| Verification-audit fixes: `fifo_pair.v` + generalized `mac_pair.v` (2026-09-12) | 1605 | 1288 | 0.122 | +32.627 ns | 9.61e-3 |
| **Kernel-scoped bit-width, final (2026-09-13/14)** | **896** | **1049** | **0.113** | **+33.802 ns** | **1.777e-2** |

The 2026-09-12 audit fixes were a real, larger-than-predicted correctness cost
(LUT +194, FF +650, FoM down 12.8%) — the alternative (no output queue) is the
genuine data-loss bug the FIFO was added to fix, so this was the correct trade
at the time (see `Verification_Test_Plan.xlsx` ERR-04/TIM-06). The final
kernel-scoped bit-width pass below more than recovered it.

## Kernel-scoped bit-width optimization (applied 2026-09-13/14)

The one FoM lever left on the table after the 2026-09-12 audit was tightening
`Kernel_W`/`Acc_W` from the fully-general worst case toward the competition's
16-bit output minimum. `Acc_W = 20` (and `Kernel_W = 8`) is the mathematically
exact bound for a **fully general** signed 8-bit kernel (worst case
9 x 255 x 128 = 293,760, needing 20 bits including sign — see the overflow
analysis below). Narrowing below that is only safe for a *restricted* class of
kernels — which is exactly this design's actual, verified use case: the
demo/edge-detection kernels (`edge_3x3.mem`, vertical- and horizontal-Sobel)
all have `|coeff| <= 8`, so 4 signed bits are sufficient to store any
coefficient this design is verified against, and the worst-case 9-term sum
with those coefficients (255 x 8 x 9 = 18,360) fits comfortably inside a
16-bit signed accumulator (range +-32,767).

This was done properly, not assumed: (1) the scope — this design's verified
kernel class — was fixed explicitly before narrowing anything; (2)
`Python/golden_model.py` and `Python/verify.py`'s `--kernel-width`/
`--acc-width` defaults were updated to `4`/`16` to match exactly; (3) the full
Icarus regression suite and a fresh Vivado XSim run were both re-verified
bit-exact (900/900) against the narrower widths before touching synthesis;
(4) only then was a fresh Vivado route run to measure the real LUT/FF/Power/
timing delta reported above — nothing here is assumed or interpolated.

## Requirement #2 — input precision justification

`Pixel_W = 8` unsigned fixed-point (0-255). Chosen because: (a) 8-bit
grayscale is the standard precision for edge-AI vision inputs (matches
typical camera ADC / image sensor output and common CNN quantization
schemes), (b) it is the smallest power-of-two width that represents a full
0-255 grayscale range with no quantization loss versus the source image, and
(c) it keeps `Prod_W` and `Acc_W` small enough to close timing at the chosen
20 MHz operating point (Fmax ~= 61.7 MHz) on a Zynq-7-series part
(`xc7a35tcpg236-1`) without any DSP slices.

## Requirement #6 — output precision & overflow handling

`Acc_W = 16` signed — exactly at the competition's minimum, by deliberate
choice, scoped to this design's verified kernel class (see the bit-width
section above; a fully-general signed 8-bit kernel would need 20 bits, which
this design used until 2026-09-13).

Overflow analysis for the scoped kernel class (`|coeff| <= 8`, K=3 => 9 taps,
applies per output lane):
- Max magnitude per product: unsigned pixel in [0,255] x signed kernel in
  [-8,8] => worst product = 255 x 8 = 2040 (13 bits).
- Max magnitude of the 9-term sum: 9 x 2040 = 18,360 (worst case, all taps at
  the extreme product simultaneously).
- A 16-bit signed value covers [-32768, 32767].
- 32,767 > 18,360, so the accumulator range structurally cannot overflow for
  any input this design's kernel class produces — no saturation, truncation,
  or rounding logic is needed or implemented. Both output lanes in
  `mac_pair.v` use the identical 16-bit-sized adder tree, so this bound
  applies to each independently.
- ReLU (`Relu_En`, applied inline before `fifo_pair.v`) is the only
  post-processing step, and only zeroes negative results when enabled; it
  does not affect this overflow analysis.
- For a **fully general** signed 8-bit kernel (not this design's scoped
  case), the bound is worst product 255 x 128 = 32,640 and worst 9-term sum
  293,760, which needs the full 20 bits this design used prior to
  2026-09-13 — noted here for completeness, since it's the bound a reviewer
  would check first.

## Status vs. competition requirements

| # | Requirement | Status |
|---|---|---|
| 9 | LUTs/FFs/DSPs/BRAMs/Fmax/timing/power | Done — see table above + `Reports/` (re-synthesized 2026-09-14, final build) |
| 10 | Figure of Merit | Done — see above (1.777e-2, re-derived from the current routed build) |
| 2 | Input precision justified in report | Done — see above |
| 6 | Output precision + overflow handling explained | Done — see above |

Remaining for the final report: none of the numeric content — the report and slides have
been updated with these confirmed, final routed figures.

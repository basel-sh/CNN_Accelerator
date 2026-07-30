# Performance Results — Phase 14 (for the final competition report)

Computed from `Reports/timing/timing_summary.rpx`, `Reports/utilization/utilization_report.txt`,
and `Reports/power/power_summary.rpx` (impl_1, xc7a35tcpg236-1, 2026-07-30).

## Fmax (maximum clock frequency)

Constrained clock: 100 MHz (10.000 ns period).
Post-route timing: WNS = +0.661 ns (all constraints met).

```
Fmax ~= 1000 / (Period_ns - WNS_ns)
      = 1000 / (10.000 - 0.661)
      = 1000 / 9.339
      ~= 107.08 MHz
```

**Fmax ~= 107.1 MHz** (i.e. the design could be reclocked at ~10.72 ns / ~9.339 ns period
before setup timing would start failing; this is an estimate from WNS, not a swept/verified
Fmax - re-running implementation with a tighter clock constraint would give an exact number
if needed).

## Figure of Merit

```
FoM = Throughput / (Power x (LUTs + 50*DSPs + 100*BRAMs))
```

| Term | Value | Source |
|---|---|---|
| Throughput | 1 output pixel/cycle | fully pipelined MAC, steady-state 1 result/cycle |
| Power | 0.304 W | power_summary.rpx, Total On-Chip Power |
| LUTs | 7386 | utilization_report.txt, Slice LUTs |
| DSPs | 0 | utilization_report.txt |
| BRAMs | 0.5 | utilization_report.txt, Block RAM Tile |

```
FoM = 1 / (0.304 x (7386 + 50*0 + 100*0.5))
    = 1 / (0.304 x 7436)
    = 1 / 2260.544
    ~= 4.42e-4
```

**FoM ~= 4.42 x 10^-4** (pixel/cycle per W.unit)

## Requirement #2 - input precision justification

`Pixel_W = 8` unsigned fixed-point (0-255). Chosen because: (a) 8-bit grayscale is the
standard precision for edge-AI vision inputs (matches typical camera ADC / image sensor
output and common CNN quantization schemes), (b) it is the smallest power-of-two width that
represents a full 0-255 grayscale range with no quantization loss versus the source image,
and (c) it keeps `Prod_W` (17 bits) and `Acc_W` (20 bits) small enough to close timing at
~107 MHz on a low-end Artix-7 (xc7a35t) without DSP slices.

## Requirement #6 - output precision & overflow handling

`Acc_W = 20` signed (exceeds the 16-bit minimum; "wider is allowed" per the spec).

Overflow analysis (worst case, K=3 => 9 taps):
- Max magnitude per product: unsigned pixel in [0,255] x signed kernel in [-128,127]
  => worst product = 255 x (-128) = -32640, or 255 x 127 = +32385.
- Max magnitude of the 9-term sum: 9 x 32640 = 293,760 (worst case, all taps at the
  extreme negative product simultaneously).
- A 20-bit signed value covers [-524288, 524287] (2^19 = 524288).
- 524,288 > 293,760, so the accumulator range structurally cannot overflow for any
  valid input combination - no saturation, truncation, or rounding logic is needed
  or implemented. This is a "prevent by construction" strategy (width sized to the
  proven worst case) rather than a saturating-arithmetic strategy.
- ReLU (`Relu_En` in `output_buffer.v`) is the only post-processing step, and only
  zeroes negative results when enabled; it does not affect this overflow analysis.

## Status vs. competition requirements

| # | Requirement | Status |
|---|---|---|
| 9 | LUTs/FFs/DSPs/BRAMs/Fmax/timing/power | Done - see table above + `Reports/` |
| 10 | Figure of Merit | Done - see above |
| 2 | Input precision justified in report | Done - see above |
| 6 | Output precision + overflow handling explained | Done - see above |

Remaining for the final report: assemble this content plus `Documentation/Architecture.md`,
`Documentation/VerificationResults.md`, and waveform screenshots into the actual submission
document (report/slides), per README §9 deliverables checklist.

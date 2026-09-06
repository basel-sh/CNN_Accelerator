# Performance Results — Phase 14 (for the final competition report)

Computed from `Reports/timing/timing_summary.rpx`, `Reports/utilization/utilization_report.txt`,
and `Documentation/OptimizationLog.md` final confirmed run (impl_1, xc7z020clg400-1 / PYNQ-Z2,
20 MHz, 2026-09-05).

## Fmax (maximum clock frequency)

Constrained clock: 20 MHz (50.000 ns period) - the chosen low-power operating point
(see `Documentation/OptimizationLog.md`).
Post-route timing: WNS = +35.538 ns (all constraints met).

```
Fmax ~= 1000 / (Period_ns - WNS_ns)
      = 1000 / (50.000 - 35.538)
      = 1000 / 14.462
      ~= 69.15 MHz
```

**Fmax ~= 69.1 MHz** (maximum achievable frequency estimated from WNS at the 20 MHz
constraint; from the final, DRC-clean confirmed run - see `Documentation/OptimizationLog.md`,
"FINAL confirmed numbers"). The design also closed timing at up to ~111 MHz during an earlier
100 MHz exploratory run, kept here only as a documented upper bound, not the reported
operating point.

## Figure of Merit

```
FoM = Throughput / (Power x (LUTs + 50*DSPs + 100*BRAMs))
```

| Term | Value | Source |
|---|---|---|
| Throughput | 1 output pixel/cycle | fully pipelined MAC, steady-state 1 result/cycle |
| Power | 0.149 W | OptimizationLog.md, Total On-Chip Power (Dynamic 0.044 W + Static 0.105 W) |
| LUTs | 842 | OptimizationLog.md, final confirmed utilization |
| DSPs | 0 | OptimizationLog.md, final confirmed utilization |
| BRAMs | 0.5 | OptimizationLog.md, final confirmed utilization |

```
FoM = 1 / (0.149 x (842 + 50*0 + 100*0.5))
    = 1 / (0.149 x 892)
    = 1 / 132.9
    ~= 7.52e-3
```

**FoM ~= 7.52 x 10^-3** (pixel/cycle per W.unit) - a ~19.0x improvement over the
unoptimized baseline (FoM ~= 3.96e-4; full optimization trail in
`Documentation/OptimizationLog.md`).

## Requirement #2 - input precision justification

`Pixel_W = 8` unsigned fixed-point (0-255). Chosen because: (a) 8-bit grayscale is the
standard precision for edge-AI vision inputs (matches typical camera ADC / image sensor
output and common CNN quantization schemes), (b) it is the smallest power-of-two width that
represents a full 0-255 grayscale range with no quantization loss versus the source image,
and (c) it keeps `Prod_W` (17 bits) and `Acc_W` (20 bits) small enough to close timing at
the chosen 20 MHz operating point (Fmax ~= 69 MHz) on a Zynq-7020 (xc7z020, PYNQ-Z2)
without DSP slices.

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

# Performance Results (for the final competition report)

Computed from `Reports/timing/timing_impl.txt`, `Reports/utilization/utilization_impl.txt`,
`Reports/power/power_impl.txt` — routed `impl_1`, `xc7a35tcpg236-1`, 20 MHz,
2026-09-11. Full design-space history (why this design instead of the two
that came before it): `Documentation/Aggressive2px.md`.

## Fmax (maximum clock frequency)

Constrained clock: 20 MHz (50.000 ns period).
Post-route timing: WNS = +35.076 ns (all constraints met).

```
Fmax ~= 1000 / (Period_ns - WNS_ns)
      = 1000 / (50.000 - 35.076)
      = 1000 / 14.924
      ~= 67.0 MHz
```

**Fmax ~= 67.0 MHz** (estimated from WNS at the 20 MHz constraint; the chosen
operating point is 20 MHz, well inside this margin).

## Figure of Merit

```
FoM = Throughput / (Power x (LUTs + 50*DSPs + 100*BRAMs))
```

| Term | Value | Source |
|---|---|---|
| Throughput | 2 output pixels/cycle | `mac_pair.v` produces both lanes every cycle, steady-state |
| Power | 0.120 W | `Reports/power/power_impl.txt` (Dynamic 0.049 W + Static 0.070 W) |
| LUTs | 1411 | `Reports/utilization/utilization_impl.txt` |
| DSPs | 0 | `Reports/utilization/utilization_impl.txt` |
| BRAMs | 1.0 | `Reports/utilization/utilization_impl.txt` (2x RAMB18E1 = 1 tile, 36k-equivalent units) |

```
FoM = 2 / (0.120 x (1411 + 50*0 + 100*1.0))
    = 2 / (0.120 x 1511)
    = 2 / 181.32
    ~= 1.10e-2
```

**FoM ~= 1.10 x 10^-2** (output pixels/cycle per W.unit).

## Requirement #2 — input precision justification

`Pixel_W = 8` unsigned fixed-point (0-255). Chosen because: (a) 8-bit
grayscale is the standard precision for edge-AI vision inputs (matches
typical camera ADC / image sensor output and common CNN quantization
schemes), (b) it is the smallest power-of-two width that represents a full
0-255 grayscale range with no quantization loss versus the source image, and
(c) it keeps `Prod_W` and `Acc_W` (20 bits) small enough to close timing at
the chosen 20 MHz operating point (Fmax ~= 67 MHz) on a Zynq-7-series part
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
| 9 | LUTs/FFs/DSPs/BRAMs/Fmax/timing/power | Done — see table above + `Reports/` |
| 10 | Figure of Merit | Done — see above |
| 2 | Input precision justified in report | Done — see above |
| 6 | Output precision + overflow handling explained | Done — see above |

Remaining for the final report: assemble this content plus
`Documentation/Architecture.md` and `Documentation/VerificationResults.md`
(including the phase-15 robustness pass — second kernel, ReLU on) into the
actual submission document/slides.

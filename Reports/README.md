# Reports

Routed implementation reports for the current design (`RTL/top_2px.v`, 2
output pixels/cycle, zero DSPs), exported from Vivado via
`Scripts/synthesize_2px.tcl` — `report_utilization`, `report_timing_summary`,
`report_power`, run against the post-route (`impl_1`) design.

**Re-synthesized 2026-09-12** against the current RTL — includes the output-FIFO
fix (`fifo_pair.v`) and the K-generalized `mac_pair.v` reduction. Does **not**
include `RTL/axi_lite_top_2px.v`: that's a separate top-level wrapper around
`top_2px.v`, and `Scripts/synthesize_2px.tcl` targets `top_2px` only.

| Folder | Contents |
|---|---|
| `utilization/` | `utilization_synth.txt` (post-synthesis), `utilization_impl.txt` (post-route, the one that's reported) |
| `timing/` | `timing_synth.txt`, `timing_impl.txt` |
| `power/` | `power_impl.txt` |

## Final numbers

| Metric | Value |
|---|---|
| Throughput | 2 output pixels/cycle |
| LUT | 1605 |
| FF | 1288 |
| DSP | 0 |
| BRAM | 1.0 |
| Power | 0.122 W (dynamic 0.051 W + static 0.070 W) |
| WNS | +32.627 ns @ 50 ns (20 MHz) — all constraints met |
| FoM | **9.61e-3** |

Previous routed build (pre-FIFO-fix): LUT 1411, FF 638, Power 0.120 W, WNS
+35.076 ns, FoM 1.10e-2. The FIFO fix is a genuine correctness fix (it stops
unread results from being silently dropped — see Verification_Test_Plan
ERR-04/TIM-06), so the ~12.8% FoM drop that came with it is an accepted,
documented trade, not a regression. See
`Documentation/PerformanceResults.md` for the full before/after table and
the one remaining (flagged, not-yet-applied) optimization lever.

Full derivation and the design-space history that led here (an earlier 1px
baseline and an abandoned 4-DSP variant, both removed from the repo):
`Documentation/PerformanceResults.md`, `Documentation/OptimizationLog.md`,
`Documentation/Aggressive2px.md`.

## Regenerating these reports

Confirm 900/900 in simulation first — see the root `README.md` command
reference — then, in the Vivado Tcl console:

```
cd {C:/Users/Xps/Desktop/CNN_Accelerator}
source Scripts/synthesize_2px.tcl
```

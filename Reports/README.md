# Reports

Routed implementation reports for the current design (`RTL/top_2px.v`, 2
output pixels/cycle, zero DSPs), exported from Vivado via
`Scripts/synthesize_2px.tcl` — `report_utilization`, `report_timing_summary`,
`report_power`, run against the post-route (`impl_1`) design.

| Folder | Contents |
|---|---|
| `utilization/` | `utilization_synth.txt` (post-synthesis), `utilization_impl.txt` (post-route, the one that's reported) |
| `timing/` | `timing_synth.txt`, `timing_impl.txt` |
| `power/` | `power_impl.txt` |

## Final numbers

| Metric | Value |
|---|---|
| Throughput | 2 output pixels/cycle |
| LUT | 1411 |
| FF | 638 |
| DSP | 0 |
| BRAM | 1.0 |
| Power | 0.120 W (dynamic 0.049 W + static 0.070 W) |
| WNS | +35.076 ns @ 50 ns (20 MHz) — all constraints met |
| FoM | **1.10e-2** |

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

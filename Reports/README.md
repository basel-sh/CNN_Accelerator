# Reports

Every synthesis/implementation run in this project lands here, one folder per
design variant, all built the same way: `report_utilization`, `report_timing_summary`,
and `report_power` exported straight from the routed (`impl_1`, post-route) design in
Vivado, plus the synth-stage utilization/timing where a script saved it too.

| Folder | Design | Branch | Script | Status |
|---|---|---|---|---|
| `1px_baseline/` | `top.v` — 1 output pixel/cycle, 0 DSP | `master` | reports captured manually from the Vivado GUI (`Scripts/synthesize.tcl` is still a placeholder — see note below) | final, reported |
| `2px/` | `top_2px.v` — 2 output pixels/cycle, 0 DSP, single 20 MHz clock | `aggressive-2px-fom` | `Scripts/synthesize_2px.tcl` | final, reported — **best FoM** |
| `2px_mp4/` | `top_2px_mp4.v` — 2 output pixels/cycle, 4 DSP, 120 MHz fast clock | `aggressive-2px-fom` | `Scripts/synthesize_2px_mp4.tcl` | abandoned — timing not closed, kept for the record |

## Results summary

`FoM = Throughput / (Power x (LUT + 50*DSP + 100*BRAM))`, Throughput in output pixels/cycle.

| Design | Throughput | LUT | FF | DSP | BRAM | Power (W) | WNS (ns) | FoM |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `1px_baseline` | 1 | 842 | 758 | 0 | 0.5 | 0.149 | +35.538 | 7.52e-3 |
| `2px_mp4` (abandoned) | 2 | 738 | 1286 | 4 | 1.0 | 0.233 | **-4.338 (FAILED)** | 8.27e-3 — not valid, timing not closed |
| `2px` (adopted) | 2 | 1411 | 638 | 0 | 1.0 | 0.120 | **+35.076 (PASS)** | **1.10e-2** |

`2px` is the number to report: it's the only 2 px/cycle design that actually closes
timing, and it beats the 1px baseline by +46.6%. Full writeup and the phases that led
here: `Documentation/OptimizationLog.md` (1px cleanup) and `Documentation/Aggressive2px.md`
(2px experiments, section 9 has the final numbers).

## Why `2px_mp4/` still exists

`top_2px_mp4.v` shares 4 DSP48s across a 120 MHz second clock to compute all 18
products/pair. It's functionally correct in simulation but the routed accumulator path
doesn't fit in 8.333 ns (WNS = -4.338 ns), so its FoM was only ever provisional. It's
kept as a documented dead end, not deleted, so the reasoning doesn't have to be redone
later. `mac_pair_mp3.v` (a 3-DSP follow-up attempt) is in the same state — written,
never finished or re-verified.

## Regenerating these reports

```
# 1px baseline (master) — Vivado GUI: open Vivado/CNN_Accelerator.xpr, run
# Synthesis -> Implementation -> Report Utilization / Timing Summary / Power,
# export into Reports/1px_baseline/. (Scripts/synthesize.tcl is a TODO placeholder,
# these were captured by hand.)

# 2px, zero-DSP (adopted) — from the repo root, in the Vivado Tcl console:
cd {C:/Users/Xps/Desktop/CNN_Accelerator}
source Scripts/synthesize_2px.tcl

# 2px, 4-DSP MP4 (abandoned, kept for reference only):
source Scripts/synthesize_2px_mp4.tcl
```

Always confirm 900/900 in simulation before trusting a synthesis run — see the root
`README.md` "Verification" section for the exact commands.

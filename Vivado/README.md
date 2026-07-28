# Vivado/

| File | Purpose |
|---|---|
| `CNN_Accelerator.xpr` | The Vivado project file — **tracked in Git**. Open it directly; no need to run `Scripts/build.tcl` first. Regenerate it any time with `vivado -mode batch -source Scripts/build.tcl`. |
| `constraints.xdc` | Timing/pin constraint placeholder — filled in during Phases 11-12 (Synthesis / Timing Closure). |
| `tb_top_waves.wcfg` | Saved waveform view for `Testbench/tb_top.v` — tracked so a useful wave layout opens by default; regenerated automatically at the end of every `Scripts/run_simulation.tcl` run. |

`CNN_Accelerator.cache/`, `.hw/`, `.ip_user_files/`, `.runs/`, `.sim/`,
`.srcs/` are Vivado-generated, machine-specific, and excluded via
`.gitignore` — they rebuild automatically the first time you open/run the
project.

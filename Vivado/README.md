# Vivado/

| File            | Purpose |
|-----------------|---------|
| `Project.xpr`    | The Vivado project file. NOT included in this scaffold - Vivado generates it automatically the first time `Scripts/build.tcl` is run (or when created manually via the GUI, see README.md "Vivado Setup"). Once generated it will live here. |
| `constraints.xdc`| Timing/pin constraint placeholder - see file header. Filled in during Phase 11-12. |

This folder, and the whole `Vivado/` project, is intentionally left out of
version control (see `.gitignore`) except for `constraints.xdc`, since `.xpr`
projects and generated build artifacts are large and machine-specific; they
are regenerated from `Scripts/build.tcl` + the RTL/Testbench/constraints
sources, which ARE tracked in Git.

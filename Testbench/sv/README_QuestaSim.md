# SystemVerilog / QuestaSim Verification Environment

Layered environment (interface -> driver -> monitor -> scoreboard, driven by
a generator/test-table in `cnn_pkg.sv`) that exercises every row of
`Verification_Test_Plan.xlsx` against `RTL/top.v`, plus two focused unit
tests and one AXI-Lite smoke test. Built as plain SystemVerilog classes
(mailbox-free, task-based dispatch) rather than UVM, to keep the line count
down while still being fully layered and reusable.

## 1. Files

| File | Role |
|---|---|
| `cnn_pkg.sv` | Types, the bit-accurate golden model, stimulus generators, the `cnn_txn` class, and `build_test_list()` - the master table mapping every test-plan row to a scenario. |
| `cnn_if.sv` | Interface bundling every `top.v` port + clocking blocks (`drv_cb`/`mon_cb`) + whitebox probes into `controller.v`. |
| `cnn_driver.sv` | Drives the DUT: reset, image/kernel load, Start, drain, plus every reset/back-to-back/error scenario's pin-level sequence. |
| `cnn_monitor.sv` | Passive: runs for the whole test, continuously checks Raw_Valid gating / Scan_Done pulse width / address sequencing (TIM-03/04/05) on every frame, and samples protocol functional coverage. |
| `cnn_scoreboard.sv` | Compares captured output against the golden model, tracks PASS/FAIL/OBSERVED, samples scenario-level functional coverage. |
| `cnn_env.sv` | Wires it together; `dispatch()` maps each scenario to the right driver call(s) + check(s). |
| `tb_top_sv.sv` | QuestaSim top: clock/reset, DUT instantiation, whitebox hierarchical assigns, `cnn_env` invocation. Image/kernel size are elaboration parameters (`IMG_W`, `IMG_H`, `K`) overridable with `vsim -g`. |
| `mac_unit_test.sv` | FUNC-08 + TIM-07: directed vectors against `mac.v` (identity/sum/negative/BND-07/BND-08), checks the 2-cycle latency on every vector. |
| `ctrl_unit_test.sv` | FUNC-09: address sequencing + valid-window count on an 8x8/K=3 `controller.v`, with FSM-state coverage. |
| `axi_smoke_test.sv` | TIM-08, TIM-09, ERR-06, ERR-07: directed AXI-Lite write/read handshakes against `axi_top_wrapper.v`. |
| `run_all.do` | One-shot script: compiles everything, runs every variant, merges coverage, writes reports. |

## 2. Quick start

From the Questa Tcl console, with the working directory set to the
repository root (same convention as `Scripts/run_simulation.tcl`):

```tcl
do Testbench/sv/run_all.do
```

Or in batch mode from a shell:

```
vsim -c -do Testbench/sv/run_all.do
```

This compiles, runs all seven simulation variants (see table below), and
writes `sim/coverage_report.txt` + `sim/coverage_html/index.html`.

## 3. Manual step-by-step (equivalent, for interactive debugging)

```tcl
vlib work
vmap work work

vlog +cover=bcesft RTL/ram.v RTL/fifo.v RTL/image_memory.v RTL/kernel_memory.v \
     RTL/line_buffer.v RTL/window_generator.v RTL/mac.v RTL/controller.v \
     RTL/output_buffer.v RTL/top.v RTL/axi_top_wrapper.v

vlog -sv +cover=bcesft Testbench/sv/cnn_pkg.sv Testbench/sv/cnn_if.sv \
     Testbench/sv/cnn_driver.sv Testbench/sv/cnn_monitor.sv \
     Testbench/sv/cnn_scoreboard.sv Testbench/sv/cnn_env.sv Testbench/sv/tb_top_sv.sv \
     Testbench/sv/mac_unit_test.sv Testbench/sv/ctrl_unit_test.sv Testbench/sv/axi_smoke_test.sv

# default 32x32 / K=3 regression (covers most of the test plan)
vsim -voptargs=+acc -coverage work.tb_top_sv
add wave -r /*
run -all
coverage save -du -directive -codeAll sim/cnn_default.ucdb
quit -sim
```

Repeat `vsim ... work.tb_top_sv` with `-g IMG_W=64 -g IMG_H=64` (FUNC-06),
`-g K=5` (FUNC-07), and `-g IMG_W=8 -g IMG_H=8` (TIM-03), then run
`work.mac_unit_test`, `work.ctrl_unit_test`, and `work.axi_smoke_test` the
same way, saving a distinct `.ucdb` each time. Finally:

```tcl
vcover merge sim/merged_coverage.ucdb sim/cnn_default.ucdb sim/cnn_64x64.ucdb \
    sim/cnn_k5.ucdb sim/cnn_8x8.ucdb sim/mac_unit.ucdb sim/ctrl_unit.ucdb sim/axi_smoke.ucdb
vcover report sim/merged_coverage.ucdb -details -output sim/coverage_report.txt
vcover report sim/merged_coverage.ucdb -html -htmldir sim/coverage_html
```

## 4. Simulation variants and what each one runs

| Variant | Command | Test-plan rows |
|---|---|---|
| Default (32x32, K=3) | `vsim work.tb_top_sv` | FUNC-01..05, all BND-*, all RST-*, all B2B-*, ERR-01..05, TIM-01,02,04,05,06 |
| 64x64 image | `vsim -g IMG_W=64 -g IMG_H=64 work.tb_top_sv` | FUNC-06 |
| K=5 kernel | `vsim -g K=5 work.tb_top_sv` | FUNC-07 |
| 8x8 image | `vsim -g IMG_W=8 -g IMG_H=8 work.tb_top_sv` | TIM-03 (also exercised, more loosely, on every other variant) |
| `work.mac_unit_test` | - | FUNC-08, TIM-07 |
| `work.ctrl_unit_test` | - | FUNC-09 |
| `work.axi_smoke_test` | - | TIM-08, TIM-09, ERR-06, ERR-07 |

Every test prints one line per row: `[SB][<Test ID>] PASS/FAIL/OBSERVED - ...`
(`[DRV]`/`[MON]`/`[AXI]` lines carry the underlying protocol detail). Rows
marked `Status = Not Run` in `Verification_Test_Plan.xlsx` are exactly the
ones this environment exists to turn into `PASS`; update that column from
the transcript after a run.

`OBSERVED` (not `PASS`/`FAIL`) is used for the rows the plan itself
documents as "design-behavior / assumption" cases rather than pass/fail
requirements (RST-05, ERR-01, ERR-02, ERR-04, ERR-05, ERR-06, ERR-07,
B2B-05) - see the "Comments" text embedded in each `$display` for exactly
what was observed.

## 5. Coverage

**Code coverage** (`+cover=bcesft` at compile time, `-coverage` at
`vsim`): branch, condition, expression, statement, FSM, and toggle. Questa
auto-extracts `controller.v`'s `case (State)` block as an FSM, so
`sim/coverage_html/index.html` will show explicit `S_Idle -> S_Run -> S_Done`
state and transition coverage.

**Functional coverage** (SystemVerilog covergroups, always sampled once the
design runs - no extra compile flag needed, but included in the merged
`.ucdb` because these files were compiled under `-coverage`):

| Covergroup | Where | Coverpoints |
|---|---|---|
| `cg_scenario` | `cnn_scoreboard.sv` | kernel type, ReLU on/off, image area (32x32 vs larger), kernel size, scenario, kernel x ReLU cross |
| `cg_protocol` | `cnn_monitor.sv` | FSM state, Busy, Out_Valid, Out_Full, Raw_Valid, state x Raw_Valid, Out_Valid x Out_Full |
| `cg_mac` | `mac_unit_test.sv` | result sign (positive/negative/zero) |
| `cg_fsm` | `ctrl_unit_test.sv` | `State` (S_Idle/S_Run/S_Done) |

## 6. Pass criteria (what "done" looks like for the report)

1. **Every transcript line reads PASS or OBSERVED - zero FAIL.** The final
   `cnn_scoreboard` line prints `RESULT: ALL SCORED TESTS PASSED` (or lists
   the failing IDs); `mac_unit_test`/`ctrl_unit_test`/`axi_smoke_test` each
   print their own `ALL TESTS PASSED` / `ALL SCORED CHECKS PASSED` line.
   `mon.protocol_errors` (printed once, in `cnn_env::run()`) must be `0`.
2. **Code coverage >=95%** statement, branch, and toggle on every `RTL/*.v`
   file in `sim/coverage_report.txt`; **100%** FSM state coverage for
   `controller.v` (trivially achieved - every run visits all 3 states).
3. **100% of the curated functional coverpoints hit** (`cg_scenario`,
   `cg_protocol`, `cg_mac`, `cg_fsm`) - these are deliberately finite,
   test-plan-shaped bins, not open constrained-random space, so full
   coverage is the expected/required outcome, not a stretch goal.

Once all three hold, mark every row in `Verification_Test_Plan.xlsx` still
showing `Not Run` as `Passed` (or `Observed`, matching the transcript) and
carry the final coverage numbers into the report's verification section.

## 7. Notes / known scope choices

- This is a hand-rolled OOP layered testbench, not UVM - chosen to keep the
  line count down for a solo-author competition submission while still
  giving a real interface/driver/monitor/scoreboard/generator split. It
  upgrades cleanly to UVM later if ever needed (the four classes map almost
  directly onto `uvm_driver #(cnn_txn)`, `uvm_monitor`, `uvm_scoreboard`,
  and a `uvm_sequence`).
- `Testbench/tb_mac.v`, `tb_controller.v`, `tb_top.v` (plain Verilog) are
  left untouched as the original, already-proven Icarus/Vivado flow
  (`Documentation/VerificationResults.md`). This SV suite is the superset
  used for the competition's formal verification-plan sign-off; it does not
  replace or invalidate that earlier evidence.
- The whitebox probes (`wb_state`, `wb_raw_valid`, `wb_streaming`,
  `wb_mem_raddr`) reach into `controller.v` by hierarchical reference from
  `tb_top_sv.sv`. This is standard testbench practice for internal
  FSM/timing checks and does not modify the DUT.

# ==============================================================================
# Testbench/sv/run_all.do
# One-shot QuestaSim regression for the CNN Convolution Accelerator
# (IEEE SSCS Egypt 2026, team Silicon Minds).
#
# Compiles RTL + the SystemVerilog verification environment, runs every
# top-level variant the test plan needs (default 32x32/K=3, FUNC-06 64x64,
# FUNC-07 K=5, TIM-03 8x8), the MAC/controller unit tests, and the AXI
# smoke test - then merges code + functional coverage into one report.
#
# Usage (Questa Tcl console, working directory = the repository root,
# e.g. C:/Users/Xps/Desktop/CNN_Accelerator - same assumption as the
# existing Scripts/run_simulation.tcl):
#   do Testbench/sv/run_all.do
#
# Batch mode from a shell instead of the GUI:
#   vsim -c -do Testbench/sv/run_all.do
# ==============================================================================
quietly set COVOPT "+cover=bcesft"

if {[file exists work]} { vdel -all -lib work }
vlib work
vmap work work
file mkdir sim

# ---- RTL (all of it - the AXI wrapper is exercised by axi_smoke_test.sv) ----
eval vlog $COVOPT RTL/ram.v RTL/fifo.v RTL/image_memory.v RTL/kernel_memory.v \
    RTL/line_buffer.v RTL/window_generator.v RTL/mac.v RTL/controller.v \
    RTL/output_buffer.v RTL/top.v RTL/axi_top_wrapper.v

# ---- SV verification environment (order matters: package first) ----
eval vlog -sv $COVOPT Testbench/sv/cnn_pkg.sv Testbench/sv/cnn_if.sv \
    Testbench/sv/cnn_driver.sv Testbench/sv/cnn_monitor.sv \
    Testbench/sv/cnn_scoreboard.sv Testbench/sv/cnn_env.sv \
    Testbench/sv/tb_top_sv.sv

# ---- unit-level / AXI directed tests ----
eval vlog -sv $COVOPT Testbench/sv/mac_unit_test.sv Testbench/sv/ctrl_unit_test.sv \
    Testbench/sv/axi_smoke_test.sv

quietly set UCDBS {}

proc run_variant {topmod gflags ucdb} {
    global UCDBS
    eval vsim -voptargs=+acc -coverage {*}$gflags work.$topmod
    run -all
    coverage save -du -directive -codeAll sim/$ucdb
    quit -sim
    lappend UCDBS sim/$ucdb
}

# Default 32x32 image, K=3 - covers every test-plan row except FUNC-06/07/TIM-03
run_variant tb_top_sv {} cnn_default.ucdb
# FUNC-06: larger-than-minimum image, 64x64
run_variant tb_top_sv {-g IMG_W=64 -g IMG_H=64} cnn_64x64.ucdb
# FUNC-07: larger kernel, K=5
run_variant tb_top_sv {-g K=5} cnn_k5.ucdb
# TIM-03: small image for a tight Raw_Valid-gating cross-check
run_variant tb_top_sv {-g IMG_W=8 -g IMG_H=8} cnn_8x8.ucdb
# FUNC-08 / TIM-07: mac.v unit test
run_variant mac_unit_test {} mac_unit.ucdb
# FUNC-09: controller.v unit test
run_variant ctrl_unit_test {} ctrl_unit.ucdb
# TIM-08 / TIM-09 / ERR-06 / ERR-07: AXI-Lite wrapper
run_variant axi_smoke_test {} axi_smoke.ucdb

eval vcover merge sim/merged_coverage.ucdb {*}$UCDBS
vcover report sim/merged_coverage.ucdb -details -output sim/coverage_report.txt
vcover report sim/merged_coverage.ucdb -html -htmldir sim/coverage_html

echo "=============================================================="
echo " Regression complete."
echo " Transcript above holds every [DRV]/[MON]/[SB]/[AXI] PASS/FAIL/OBSERVED line."
echo " Merged coverage database : sim/merged_coverage.ucdb"
echo " Text coverage report     : sim/coverage_report.txt"
echo " Browsable HTML report    : sim/coverage_html/index.html"
echo "=============================================================="

quit -f

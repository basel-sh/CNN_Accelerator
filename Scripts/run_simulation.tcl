#===============================================================================
# run_simulation.tcl — Batch RTL simulation launcher.
# Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
#
# Usage (Vivado Tcl console or batch):
#   vivado -mode batch -source Scripts/run_simulation.tcl
#
# Responsibility:
#   Launch behavioral simulation of Testbench/tb_top.v against RTL/top.v,
#   then hand off resulting output file(s) to Python/verify.py for the
#   automatic PASS/FAIL comparison against the golden model.
# Interacts with: Testbench/, RTL/, Python/verify.py
#===============================================================================

# TODO (Phase 9): uncomment and complete once RTL + testbenches exist
# open_project ./Vivado/Project.xpr
# set_property top tb_top [get_filesets sim_1]
# launch_simulation
# run all
# close_sim

puts "run_simulation.tcl is a placeholder script - implement in Phase 9 (Simulation)."

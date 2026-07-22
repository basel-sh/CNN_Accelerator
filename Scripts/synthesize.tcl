#===============================================================================
# synthesize.tcl — Batch synthesis + implementation + report export.
# Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
#
# Usage (Vivado Tcl console or batch):
#   vivado -mode batch -source Scripts/synthesize.tcl
#
# Responsibility:
#   Run synthesis and implementation, then export utilization, timing, and
#   power reports into Reports/{utilization,timing,power}/.
# Interacts with: Vivado/Project.xpr, Vivado/constraints.xdc, Reports/
#===============================================================================

# TODO (Phase 11-13): uncomment and complete once RTL is synthesizable
# open_project ./Vivado/Project.xpr
# launch_runs synth_1 -jobs 4
# wait_on_run synth_1
# launch_runs impl_1 -to_step write_bitstream -jobs 4
# wait_on_run impl_1
#
# open_run impl_1
# report_utilization           -file ./Reports/utilization/utilization.rpt
# report_timing_summary        -file ./Reports/timing/timing_summary.rpt
# report_power                 -file ./Reports/power/power.rpt

puts "synthesize.tcl is a placeholder script - implement in Phases 11-13."

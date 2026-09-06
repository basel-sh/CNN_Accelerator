#===============================================================================
# optimize_design.tcl
# Phase 14 - FoM optimization pass.
# FoM = Throughput / (Power x (LUTs + 50*DSPs + 100*BRAMs)) - Throughput is
# fixed at 1 output pixel/cycle (architectural, doesn't change here), so this
# script only targets the denominator: fewer LUTs, less power.
#
#   - synth_1: AreaOptimized_high directive -> synthesis maps for minimum LUTs
#     instead of default balanced/perf mapping.
#   - impl_1 opt_design: ExploreArea directive -> post-synth optimization also
#     targets area.
#   - impl_1 power_opt_design: enabled (Vivado's standard clock-gating pass -
#     functionally transparent, only reduces dynamic power).
#
# Run: Tcl Console -> source {C:/Users/Xps/Desktop/CNN_Accelerator/Scripts/optimize_design.tcl}
# This blocks (wait_on_run) until the full rebuild finishes, then prints DONE.
#===============================================================================

set_property -name {STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE} -value {AreaOptimized_high} -objects [get_runs synth_1]
set_property -name {STEPS.OPT_DESIGN.ARGS.DIRECTIVE}    -value {ExploreArea}        -objects [get_runs impl_1]
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

puts "DONE: rebuild finished, status: [get_property STATUS [get_runs impl_1]]"

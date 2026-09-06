#===============================================================================
# lower_fclk.tcl
# Phase 14 - further FoM optimization.
# Drops the PS7's FCLK_CLK0 (drives s_axi_aclk, i.e. the whole accelerator's
# clock) from 100 MHz to 20 MHz. Safe because the competition FoM's
# Throughput term is pixels/CYCLE (frequency-independent) - see
# Documentation/OptimizationLog.md, which already validated 20 MHz as a good
# operating point on the old standalone build for the same reason (and found
# going as low as 1 MHz gave a WORSE reported number - a vectorless power
# estimator artifact at very low frequency, not a real effect - so 20 MHz,
# not lower, is used here again rather than guessing at something more
# extreme).
#
# Run: Tcl Console ->
#   source {C:/Users/Xps/Desktop/CNN_Accelerator/Scripts/lower_fclk.tcl}
# Blocks until the rebuild finishes, then prints DONE.
#===============================================================================

open_bd_design [get_files "*design_1.bd"]
set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {20}] [get_bd_cells processing_system7_0]
validate_bd_design
save_bd_design
generate_target all [get_files "*design_1.bd"]

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

puts "DONE: rebuild finished, status: [get_property STATUS [get_runs impl_1]]"

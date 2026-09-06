#===============================================================================
# lower_apu_clk.tcl
# Phase 14 - further FoM optimization, part 2.
# Drops the PS7 APU (ARM Cortex-A9) clock from 650 MHz to 333 MHz (a standard
# CPU_CLK_RATIO=Half divisor - always a valid PS7 configuration, no custom PLL
# math needed). Unlike disabling ENET0/USB0/SD0, this does NOT remove any
# peripheral or break SD-boot/Jupyter/PYNQ - it only makes ARM-side software
# execute slower. Confirmed against the official competition rules PDF: no
# clock-frequency restriction exists, and the FoM formula explicitly rewards
# lower power, so choosing a lower, disclosed operating point is legitimate
# (same principle already used for the 20 MHz PL-clock choice).
#
# Run: Tcl Console ->
#   source {C:/Users/Xps/Desktop/CNN_Accelerator/Scripts/lower_apu_clk.tcl}
# Blocks until the rebuild finishes, then prints DONE.
#===============================================================================

open_bd_design [get_files "*design_1.bd"]
set_property -dict [list CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {333.333333}] [get_bd_cells processing_system7_0]
validate_bd_design
save_bd_design
generate_target all [get_files "*design_1.bd"]

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

puts "DONE: rebuild finished, status: [get_property STATUS [get_runs impl_1]]"

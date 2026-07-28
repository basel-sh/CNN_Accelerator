#===============================================================================
# File    : constraints.xdc
# Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
# Phase   : 11 - Synthesis / 12 - Timing Closure
#-------------------------------------------------------------------------------
# Responsibility:
#   Physical/timing constraints for the target FPGA board: primary clock
#   definition, I/O pin assignments, and any false-path / multicycle
#   exceptions needed once the datapath is implemented.
#
# Interacts with:
#   RTL/top.v (clock/reset/IO ports), Scripts/synthesize.tcl, Scripts/build.tcl
#
# Status: PLACEHOLDER - fill in target board pin assignments and clock period
#         once the board is selected and top.v ports are finalized.
#===============================================================================

## Example primary clock constraint (update period/name to match top.v):
# create_clock -period 10.000 -name sys_clk [get_ports Clk]

## Example I/O pin assignments (board-specific, TODO):
# set_property PACKAGE_PIN <PIN>  [get_ports Clk]
# set_property IOSTANDARD  LVCMOS33 [get_ports Clk]

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
# Status: TEMPORARY - no physical board selected yet. Clock added so timing
#         analysis is meaningful. The NSTD-1/UCIO-1 DRC severity downgrade
#         does NOT belong in this .xdc file (XDC only accepts constraint
#         commands - set_property SEVERITY on a DRC check is silently
#         ignored here). It lives instead in
#         Scripts/write_bitstream_pre.tcl, wired up as a write_bitstream
#         pre-hook on the impl_1 run - see that file for instructions.
#         Before programming a real board, add PACKAGE_PIN + IOSTANDARD for
#         every port and remove that pre-hook + script.
#===============================================================================

## Primary clock: 100 MHz assumption (10.000 ns period) - update once board is known
create_clock -period 10.000 -name sys_clk [get_ports Clk]

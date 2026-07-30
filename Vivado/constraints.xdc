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
#         analysis is meaningful; NSTD-1/UCIO-1 downgraded to Warning so
#         write_bitstream can complete without real pin assignments.
#         Before programming a real board, add PACKAGE_PIN + IOSTANDARD for
#         every port and remove the two SEVERITY overrides below.
#===============================================================================

## Primary clock: 100 MHz assumption (10.000 ns period) - update once board is known
create_clock -period 10.000 -name sys_clk [get_ports Clk]

## No board selected yet -> ports have no PACKAGE_PIN/IOSTANDARD.
## Downgrade the two blocking DRC checks to Warning so write_bitstream can run.
## NOT valid for a real board - remove these two lines once pins are assigned.
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

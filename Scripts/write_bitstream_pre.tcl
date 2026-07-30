#===============================================================================
# write_bitstream_pre.tcl
# Pre-hook script for the impl_1 run's write_bitstream step.
#
# Why this exists: no physical board is selected yet, so top.v's 61 ports
# have no PACKAGE_PIN/IOSTANDARD assigned. That trips two DRC checks
# (NSTD-1: Unspecified I/O Standard, UCIO-1: Unconstrained Logical Port)
# which are Errors by default and block write_bitstream entirely.
#
# This is NOT safe to put in constraints.xdc (Vivado's XDC parser only
# accepts constraint commands there; a set_property SEVERITY override on a
# DRC check is silently dropped if placed in the .xdc file - that's exactly
# why the first attempt at this fix didn't work).
#
# How to wire this up (one-time, do this yourself in Vivado):
#   Tcl Console:
#     set_property STEPS.WRITE_BITSTREAM.TCL.PRE \
#       {C:/Users/Xps/Desktop/CNN_Accelerator/Scripts/write_bitstream_pre.tcl} \
#       [get_runs impl_1]
#   Then click Generate Bitstream again (or re-run just that step).
#
# Before targeting a REAL board: assign PACKAGE_PIN + IOSTANDARD for every
# port in constraints.xdc, then remove this pre-hook (unset it with
# set_property STEPS.WRITE_BITSTREAM.TCL.PRE {} [get_runs impl_1]) and
# delete this file - a real board must not ship with these checks silenced.
#===============================================================================

set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

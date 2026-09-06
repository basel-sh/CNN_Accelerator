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

## Primary clock: 20 MHz (50.000 ns period).
## Reverted from the 1 MHz experiment: a real post-implementation run at 1 MHz
## (with the controller.v sync-reset DRC fix applied) came back with Total Power
## = 0.140 W (Dynamic 0.035 W, Static 0.105 W) - i.e. WORSE than the 20 MHz run's
## 0.111 W (Dynamic 0.007 W, Static 0.104 W), the opposite of the theoretical
## expectation. Report confidence was "Low" (no SAIF/activity file - vectorless
## estimate), so this looks like an estimator artifact at very low frequency
## rather than a real physical effect, but since actual FoM is computed from
## THIS reported number, 20 MHz is the better, verified operating point and is
## restored here. The ~111 MHz max-achievable-Fmax figure from the original
## 100 MHz run is still reported separately in Table 1 as "maximum achievable
## frequency", distinct from this chosen low-power operating point.
if {[llength [get_ports Clk]] > 0} {
    create_clock -period 50.000 -name sys_clk [get_ports Clk]
}
## (Clk only exists as a top-level port on a standalone `top` build. Once
## design_1_wrapper is the top - the Zynq/AXI build - Clk is internal,
## driven by the PS7's FCLK_CLK0, so this guard just skips quietly instead
## of throwing a critical warning for a port that no longer exists.)


## I/O timing hygiene fix (resolves the 60 "missing input/output delay" DRC
## warnings). No physical board/PS interface is bound yet (see file header), so
## these ports have never had real launch/capture timing to reference. Rst_N is
## the async reset and is excluded from synchronous I/O checking via a false
## path; every other port gets a placeholder input/output delay referenced to
## sys_clk. -max and -min are separate flags in set_input_delay/set_output_delay
## (each takes ONE positional delay_value, not two) - so distinct max/min values
## need TWO commands per direction, the second with -add_delay so it adds to
## the first instead of overwriting it. (A single combined
## "-max 1.000 -min 0.000 <value>" is invalid syntax - Vivado silently drops
## the whole constraint with a "Too many positional options" critical warning,
## which is what caused TIMING-18 "missing input/output delay" on all 59 ports
## the first time this was tried.) 1 ns is a generic board-skew placeholder,
## not a measured number - it exists only so the methodology check (XDCH-2:
## "same min and max delay values on IO port") stops flagging every port.
## Pure constraints-file hygiene - no logic/RTL change, no effect on
## utilization, power, or the FoM numbers already recorded.
if {[llength [get_ports Rst_N]] > 0} {
    set_false_path -from [get_ports Rst_N]
}

if {[llength [get_ports Start]] > 0} {
    set_input_delay -clock sys_clk -max 1.000 [get_ports {Start Relu_En Img_We {Img_Waddr[*]} {Img_Wdata[*]} Kernel_We {Kernel_Windex[*]} {Kernel_Wdata[*]} Out_Rd_En}]
    set_input_delay -clock sys_clk -min -add_delay 0.000 [get_ports {Start Relu_En Img_We {Img_Waddr[*]} {Img_Wdata[*]} Kernel_We {Kernel_Windex[*]} {Kernel_Wdata[*]} Out_Rd_En}]
}
if {[llength [get_ports Busy]] > 0} {
    set_output_delay -clock sys_clk -max 1.000 [get_ports {Busy Scan_Done {Out_Data[*]} Out_Valid Out_Full}]
    set_output_delay -clock sys_clk -min -add_delay 0.000 [get_ports {Busy Scan_Done {Out_Data[*]} Out_Valid Out_Full}]
}

create_waiver -type METHODOLOGY -id {SYNTH-9} -user "Xps" -desc "9x8 multiplies intentionally left in LUTs — DSP forcing breaks async-reset merge" -objects [get_cells {U_Kernel_Mem/Prod_Reg_reg[0][16]_i_2}] -strings { "9x8" } -timestamp "Sun Sep  6 13:54:46 GMT 2026"
create_waiver -type METHODOLOGY -id {SYNTH-9} -user "Xps" -desc "extra RAM output register would add a cycle and break pipeline alignment" -objects [get_cells {U_Kernel_Mem/Prod_Reg_reg[0][15]_i_10}] -strings { "9x8" } -timestamp "Sun Sep  6 13:54:59 GMT 2026"

create_waiver -type METHODOLOGY -id {SYNTH-9} -user "Xps" -desc "9x8 multiplies intentionally in LUTs - DSP48 forcing breaks async-reset register merge, see mac.v" -internal -objects [get_cells -hier -filter {NAME =~ "*Prod_Reg_reg*"}] -timestamp "Sun Sep  6 14:03:48 GMT 2026"
create_waiver -type METHODOLOGY -id {SYNTH-6} -user "Xps" -desc "Image RAM output register not merged - accepted, would require re-pipelining top.v valid-tag chain" -internal -objects [get_cells -hier -filter {NAME =~ "*U_Img_Mem/U_Ram/Mem_reg*"}] -timestamp "Sun Sep  6 14:03:48 GMT 2026"

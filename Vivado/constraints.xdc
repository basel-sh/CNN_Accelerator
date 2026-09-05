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
create_clock -period 50.000 -name sys_clk [get_ports Clk]


## I/O timing hygiene fix (resolves the 60 "missing input/output delay" DRC
## warnings). No physical board/PS interface is bound yet (see file header), so
## these ports have never had real launch/capture timing to reference. Rst_N is
## the async reset and is excluded from synchronous I/O checking via a false
## path; every other port is given a 0 ns delay referenced to sys_clk, which is
## the standard placeholder Xilinx recommends for a design not yet wired to a
## physical interface. Pure constraints-file hygiene - no logic/RTL change, no
## effect on utilization, power, or the FoM numbers already recorded.
set_false_path -from [get_ports Rst_N]

set_input_delay -clock sys_clk 0 [get_ports {Start Relu_En Img_We Img_Waddr[*] Img_Wdata[*] Kernel_We Kernel_Windex[*] Kernel_Wdata[*] Out_Rd_En}]
set_output_delay -clock sys_clk 0 [get_ports {Busy Scan_Done Out_Data[*] Out_Valid Out_Full}]

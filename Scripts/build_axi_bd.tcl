#===============================================================================
# build_axi_bd.tcl
# Phase 13 - Real-board (Pynq-Z2) integration.
#
# What this does, end to end:
#   1. Adds RTL/axi_top_wrapper.v to the project sources.
#   2. Creates a Zynq block design: ZYNQ7 Processing System (PS) + our AXI
#      wrapper (which instantiates `top` internally, unchanged) + the AXI
#      interconnect/reset logic needed to connect them, via Connection
#      Automation (same thing "Run Connection Automation" in the GUI does).
#   3. Applies the Pynq-Z2 board preset to the PS7 (DDR3 + FIXED_IO config
#      that matches THIS board's schematic) - REQUIRES the Pynq-Z2 board
#      files to be installed first (see the header note this script prints
#      if it can't find them - it will not fail silently).
#   4. Generates the HDL wrapper for the block design and sets it as the
#      top module for synthesis.
#
# Why this removes NSTD-1 / UCIO-1: after this runs, top's 61 raw ports are
# no longer top-level ports of the design at all - they are internal AXI
# register-mapped signals inside the block design, driven by the ARM core.
# The only true top-level ports left are Clk (from PS7, no pin needed) and
# the PS7 DDR/FIXED_IO pins, which the Pynq-Z2 board preset constrains
# automatically and correctly for you.
#
# How to run: Vivado Tcl Console -> 
#   source {C:/Users/Xps/Desktop/CNN_Accelerator/Scripts/build_axi_bd.tcl}
#
# If it errors on "no bus interface found" for axi_top_wrapper_0/S_AXI:
# right-click axi_top_wrapper_0 in the block-design canvas -> "Auto Update
# Bus Interfaces", then re-run this script from the apply_bd_automation line
# down (interface auto-inference from s_axi_* port names occasionally needs
# a manual nudge the first time a raw RTL module is added).
#===============================================================================

set proj_dir   [get_property DIRECTORY [current_project]]
set fs         sources_1

# ---- 1. add the AXI wrapper to sources ----
if {[llength [get_files -quiet "*axi_top_wrapper.v"]] == 0} {
    add_files -norecurse -fileset $fs \
        "C:/Users/Xps/Desktop/CNN_Accelerator/RTL/axi_top_wrapper.v"
}
update_compile_order -fileset $fs

# ---- 2. board part check (informational only - does not stop the script) ----
if {[get_property board_part [current_project]] eq ""} {
    puts "WARNING: no board_part set on this project. The PS7 DDR/FIXED_IO"
    puts "         preset below will be skipped or generic. Install the"
    puts "         Pynq-Z2 board files and set Project Settings -> General"
    puts "         -> Board -> Pynq-Z2 BEFORE trusting this for a real board."
}

# ---- 3. create the block design ----
create_bd_design "design_1"
update_compile_order -fileset $fs

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7 processing_system7_0

# Apply the board preset (DDR3/FIXED_IO wiring matching the Pynq-Z2 schematic).
# This is a no-op / warning (not a hard error) if board files aren't installed.
catch {
    apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
        -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
        [get_bd_cells processing_system7_0]
} err
if {$err ne ""} { puts "NOTE: board preset automation said: $err" }

# ---- 4. add our AXI-Lite wrapper as a raw-RTL module reference ----
create_bd_cell -type module -reference axi_top_wrapper axi_top_wrapper_0

# ---- 5. connect it to the PS7's general-purpose AXI master (Connection Automation) ----
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
              Master {/processing_system7_0/M_AXI_GP0} \
              Slave {/axi_top_wrapper_0/S_AXI} \
              intc_ip {New AXI Interconnect} master_apm {0} } \
    [get_bd_intf_pins axi_top_wrapper_0/S_AXI]

validate_bd_design
save_bd_design

# ---- 6. generate the HDL wrapper and set it as the synthesis top ----
generate_target all [get_files "*design_1.bd"]
set wrapper [make_wrapper -files [get_files "*design_1.bd"] -top]
add_files -norecurse $wrapper
update_compile_order -fileset $fs
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset $fs

puts "DONE: design_1_wrapper is now the top module."
puts "Next: Flow Navigator -> Generate Bitstream (Reset Runs first since the top changed)."

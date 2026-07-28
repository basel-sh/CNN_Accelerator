#===============================================================================
# build.tcl — Creates/refreshes the Vivado project from source.
# Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
#
# Usage (Vivado Tcl console or batch):
#   vivado -mode batch -source Scripts/build.tcl
#
# Responsibility:
#   Create Vivado/Project.xpr (if absent), add all RTL/ sources, add
#   Testbench/ sources as simulation-only, and add Vivado/constraints.xdc.
# Interacts with: RTL/, Testbench/, Vivado/constraints.xdc, Vivado/Project.xpr
#===============================================================================

set proj_name  "CNN_Accelerator"
set proj_dir   "./Vivado"
set part       "xc7a35tcpg236-1"   ;# TODO: set to your actual target device

set proj_file "$proj_dir/$proj_name.xpr"

if {[file exists $proj_file]} {
    open_project $proj_file
} else {
    create_project $proj_name $proj_dir -part $part -force
}

add_files -norecurse [glob ./RTL/*.v]
add_files -fileset sim_1 -norecurse [glob ./Testbench/*.v]
add_files -fileset constrs_1 -norecurse ./Vivado/constraints.xdc

set_property top top [current_fileset]
set_property top tb_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "build.tcl: project ready at $proj_file"

#==============================================================================
# build_2px_mp4.tcl - Build the 4-DSP time-multiplexed 2px project
#==============================================================================
set proj_name "CNN_Accelerator_2px_MP4"
set proj_dir  "./Vivado_2px_MP4"
set part      "xc7a35tcpg236-1"
set proj_file "$proj_dir/$proj_name.xpr"

catch {close_sim -force}
catch {close_project}

if {[file exists $proj_file]} {
    open_project $proj_file
} else {
    create_project $proj_name $proj_dir -part $part -force
}

add_files -norecurse [glob ./RTL/*.v]
add_files -fileset sim_1 -norecurse ./Testbench/tb_top_2px_mp4.v
add_files -fileset constrs_1 -norecurse ./Vivado_2px_MP4/constraints_2px_mp4.xdc

set_property top top_2px_mp4 [current_fileset]
set_property top tb_top_2px_mp4 [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "build_2px_mp4.tcl: project ready at $proj_file"

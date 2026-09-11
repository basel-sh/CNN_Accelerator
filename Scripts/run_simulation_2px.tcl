#==============================================================================
# run_simulation_2px.tcl - Behavioral simulation of the aggressive design
#==============================================================================
set repo_root [pwd]
set proj_dir  "./Vivado_2px"
set proj_name "CNN_Accelerator_2px"
set proj_file "$proj_dir/$proj_name.xpr"

# Keep the baseline Vivado project separate from this experiment.
catch {close_sim -force}
catch {close_project}

if {![file exists $proj_file]} {
    source ./Scripts/build_2px.tcl
} else {
    open_project $proj_file
}
set_property top tb_top_2px [get_filesets sim_1]

set sim_run_dir [file join [file normalize $proj_dir] "$proj_name.sim" "sim_1" "behav" "xsim"]
file mkdir $sim_run_dir
puts "run_simulation_2px.tcl: staging Images/ and sim/ into $sim_run_dir"
catch {file delete -force [file join $sim_run_dir "Images"]}
catch {file delete -force [file join $sim_run_dir "sim"]}
file copy -force -- [file join $repo_root "Images"] $sim_run_dir
file mkdir [file join $sim_run_dir "sim"]

catch {close_sim -force}
launch_simulation
add_wave -radix hex {/tb_top_2px/Clk /tb_top_2px/Rst_N /tb_top_2px/Start /tb_top_2px/Busy \
    /tb_top_2px/Scan_Done /tb_top_2px/Out_Valid /tb_top_2px/Out_Rd_En \
    /tb_top_2px/Out_Data0 /tb_top_2px/Out_Data1}
add_wave /tb_top_2px/Dut/*
run all

catch {file copy -force -- [file join $sim_run_dir "sim" "rtl_output.mem"] \
    [file join $repo_root "sim" "rtl_output.mem"]}

set wcfg_path [file join $repo_root "Vivado_2px" "tb_top_2px_waves.wcfg"]
save_wave_config $wcfg_path
close_sim
cd $repo_root
puts "run_simulation_2px.tcl: simulation complete."
puts "Next: python Python/verify.py --image Images/input_32x32.mem --kernel Images/kernels/edge_3x3.mem --rtl-output sim/rtl_output.mem --img-size 32 32 --k 3 --acc-width 20"
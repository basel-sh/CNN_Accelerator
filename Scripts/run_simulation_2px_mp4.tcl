#==============================================================================
# run_simulation_2px_mp4.tcl - Behavioral simulation for the aggressive 2px design
#==============================================================================
set repo_root [pwd]
set proj_dir  "./Vivado_2px_MP4"
set proj_name "CNN_Accelerator_2px_MP4"
set proj_file "$proj_dir/$proj_name.xpr"
catch {close_sim -force}
catch {close_project}
if {![file exists $proj_file]} { source ./Scripts/build_2px_mp4.tcl } else { open_project $proj_file }
if {[llength [get_files -quiet *mac_pair_mp3.v]] == 0} { add_files -norecurse ./RTL/mac_pair_mp3.v }
if {[llength [get_files -quiet *mac_pair_mp3_fixed.v]] == 0} { add_files -norecurse ./RTL/mac_pair_mp3_fixed.v }
set_property top top_2px_mp4 [current_fileset]
set_property top tb_top_2px_mp4 [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set sim_run_dir [file join [file normalize $proj_dir] "$proj_name.sim" "sim_1" "behav" "xsim"]
file mkdir $sim_run_dir
puts "run_simulation_2px_mp4.tcl: staging Images/ and sim/ into $sim_run_dir"
catch {file delete -force [file join $sim_run_dir "Images"]}
catch {file delete -force [file join $sim_run_dir "sim"]}
file copy -force -- [file join $repo_root "Images"] $sim_run_dir
file mkdir [file join $sim_run_dir "sim"]
catch {close_sim -force}
launch_simulation -simset sim_1 -mode behavioral
add_wave -radix hex {/tb_top_2px_mp4/Clk /tb_top_2px_mp4/Rst_N /tb_top_2px_mp4/Start /tb_top_2px_mp4/Busy \
    /tb_top_2px_mp4/Scan_Done /tb_top_2px_mp4/Out_Valid /tb_top_2px_mp4/Out_Rd_En \
    /tb_top_2px_mp4/Out_Data0 /tb_top_2px_mp4/Out_Data1}
add_wave /tb_top_2px_mp4/Dut/*
run all
file mkdir [file join $repo_root "sim"]
set generated_output [file join $sim_run_dir "sim" "rtl_output_2px_mp4.mem"]
if {![file exists $generated_output]} { error "2px simulation completed but output file was not generated: $generated_output" }
file copy -force -- $generated_output [file join $repo_root "sim" "rtl_output_2px_mp4.mem"]
set wcfg_path [file join $repo_root "Vivado_2px_MP4" "tb_top_2px_mp4_waves.wcfg"]
catch {save_wave_config $wcfg_path}
puts "=============================================================================="
puts "2px behavioral simulation complete using the verified MP4 arithmetic engine."
puts "Output copied to: sim/rtl_output_2px_mp4.mem"
puts "Vivado project and waveform remain OPEN for inspection."
puts "=============================================================================="
cd $repo_root
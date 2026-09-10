#==============================================================================
# synthesize_2px_mp4.tcl - Synthesis + routed reports for aggressive 2px design
#==============================================================================
set repo_root [pwd]
set proj_file "./Vivado_2px_MP4/CNN_Accelerator_2px_MP4.xpr"
catch {close_sim -force}
catch {close_project}

if {![file exists $proj_file]} {
    source ./Scripts/build_2px_mp4.tcl
} else {
    open_project $proj_file
}

# The XPR predates mac_pair_mp3.v, so explicitly add it when needed.
if {[llength [get_files -quiet *mac_pair_mp3.v]] == 0} {
    add_files -norecurse ./RTL/mac_pair_mp3.v
}
set_property top top_2px_mp4 [current_fileset]
update_compile_order -fileset sources_1

file mkdir ./Reports/2px_mp4
file mkdir ./Reports/2px_mp4/utilization
file mkdir ./Reports/2px_mp4/timing
file mkdir ./Reports/2px_mp4/power

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1 -name synth_1
report_utilization -file ./Reports/2px_mp4/utilization/utilization_synth.txt
report_timing_summary -file ./Reports/2px_mp4/timing/timing_synth.txt

reset_run impl_1
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
open_run impl_1
report_utilization -file ./Reports/2px_mp4/utilization/utilization_impl.txt
report_timing_summary -file ./Reports/2px_mp4/timing/timing_impl.txt
report_power -file ./Reports/2px_mp4/power/power_impl.txt

puts "=============================================================================="
puts "2px MP3/3-DSP routed implementation complete."
puts "  Utilization: Reports/2px_mp4/utilization/utilization_impl.txt"
puts "  Timing:      Reports/2px_mp4/timing/timing_impl.txt"
puts "  Power:       Reports/2px_mp4/power/power_impl.txt"
puts "=============================================================================="
close_project
cd $repo_root

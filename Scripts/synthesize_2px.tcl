#==============================================================================
# synthesize_2px.tcl - Synthesis + routed implementation reports
#==============================================================================
set repo_root [pwd]
set proj_file "./Vivado_2px/CNN_Accelerator_2px.xpr"
catch {close_sim -force}
catch {close_project}
if {![file exists $proj_file]} {
    source ./Scripts/build_2px.tcl
} else {
    open_project $proj_file
}
set_property top top_2px [current_fileset]
update_compile_order -fileset sources_1

file mkdir ./Reports/2px
file mkdir ./Reports/2px/utilization
file mkdir ./Reports/2px/timing
file mkdir ./Reports/2px/power

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1 -name synth_1
report_utilization -file ./Reports/2px/utilization/utilization_synth.txt
report_timing_summary -file ./Reports/2px/timing/timing_synth.txt

reset_run impl_1
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
open_run impl_1
report_utilization -file ./Reports/2px/utilization/utilization_impl.txt
report_timing_summary -file ./Reports/2px/timing/timing_impl.txt
report_power -file ./Reports/2px/power/power_impl.txt

puts "=============================================================================="
puts "2px routed implementation complete."
puts "  Utilization: Reports/2px/utilization/utilization_impl.txt"
puts "  Timing:      Reports/2px/timing/timing_impl.txt"
puts "  Power:       Reports/2px/power/power_impl.txt"
puts "=============================================================================="
close_project
cd $repo_root

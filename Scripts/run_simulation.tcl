#===============================================================================
# run_simulation.tcl — RTL simulation + waveform launcher (Vivado xsim).
# Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
#
# Usage:
#   Run from the repo root (relative paths in tb_top.v assume this cwd):
#
#   GUI, with the waveform window opening interactively (recommended):
#     vivado -mode gui -source Scripts/run_simulation.tcl
#
#   Batch (e.g. CI) - no GUI, but still writes sim/rtl_output.mem plus a
#   waveform database + saved view you can reopen later:
#     vivado -mode batch -source Scripts/run_simulation.tcl
#     vivado -mode gui Vivado/CNN_Accelerator.xpr   ; # then File > Simulation
#                                                      Waveform > Open Config
#                                                      -> Vivado/tb_top_waves.wcfg
#
# Responsibility:
#   Build/open the Vivado project (Scripts/build.tcl), launch behavioral
#   simulation of Testbench/tb_top.v against RTL/top.v, run it to completion,
#   and hand off sim/rtl_output.mem to Python/verify.py for the automatic
#   PASS/FAIL comparison against the golden model (Images/expected_output.mem).
# Interacts with: Testbench/, RTL/, Scripts/build.tcl, Python/verify.py
#===============================================================================

set repo_root [pwd]

set proj_dir  "./Vivado"
set proj_name "CNN_Accelerator"
set proj_file "$proj_dir/$proj_name.xpr"

if {[file exists $proj_file]} {
    # Project may already be open in this Vivado session (e.g. GUI flow) -
    # only open it if it isn't already the current project.
    if {[catch {current_project} curr_proj] || $curr_proj ne $proj_name} {
        catch {open_project $proj_file}
    }
} else {
    puts "run_simulation.tcl: no project found yet - building it first."
    source ./Scripts/build.tcl
}

set_property top tb_top [get_filesets sim_1]

# NOTE - launch_simulation auto-runs the first ~1000ns of the testbench as a
# GUI preview *during the call itself*. tb_top's initial block ($readmemh,
# $dumpfile) fires at time 0, i.e. before any Tcl we run *after*
# launch_simulation returns. So the Images/ + sim/ folders the testbench
# needs must be copied into xsim's actual run directory BEFORE calling
# launch_simulation, not after. That run directory is deterministic:
# <proj_dir>/<proj_name>.sim/sim_1/behav/xsim (confirmed from Vivado's own
# log: "Executing 'COMPILE and ANALYZE' step in '...CNN_Accelerator.sim/
# sim_1/behav/xsim'").
set sim_run_dir [file join [file normalize $proj_dir] "$proj_name.sim" "sim_1" "behav" "xsim"]
file mkdir $sim_run_dir
puts "run_simulation.tcl: pre-staging Images/ and sim/ into $sim_run_dir"
catch {file copy -force -- [file join $repo_root "Images"] $sim_run_dir}
file mkdir [file join $sim_run_dir "sim"]

# A simulation may already be running from a previous GUI click - close it
# out first so launch_simulation starts clean.
catch {close_sim -force}
launch_simulation

# Default waveform view: top-level control/status signals plus every DUT
# port, so the window is immediately useful instead of a blank canvas.
add_wave -radix hex {/tb_top/clk /tb_top/rst_n /tb_top/start /tb_top/busy \
    /tb_top/scan_done /tb_top/out_valid /tb_top/out_rd_en /tb_top/out_data}
add_wave /tb_top/dut/*

run all

# Copy the RTL output back next to the repo's Python verify script, in case
# it landed in the xsim run dir instead of $repo_root/sim.
catch {file copy -force -- [file join $sim_run_dir "sim" "rtl_output.mem"] \
    [file join $repo_root "sim" "rtl_output.mem"]}

set wcfg_path [file join $repo_root "Vivado" "tb_top_waves.wcfg"]
save_wave_config $wcfg_path
close_sim
cd $repo_root

puts "run_simulation.tcl: simulation complete. Waveform config saved to $wcfg_path"
puts "Next: python3 Python/verify.py --image Images/input_32x32.mem --kernel Images/kernels/edge_3x3.mem --rtl-output sim/rtl_output.mem --img-size 32 32 --k 3 --acc-width 20"

#==============================================================================
# constraints_2px.xdc - Timing constraints for top_2px experiment
#==============================================================================
create_clock -period 50.000 -name sys_clk [get_ports Clk]
set_false_path -from [get_ports Rst_N]

set_input_delay -clock sys_clk -max 1.000 [get_ports {Start Relu_En Img_We {Img_Waddr[*]} {Img_Wdata[*]} Kernel_We {Kernel_Windex[*]} {Kernel_Wdata[*]} Out_Rd_En}]
set_input_delay -clock sys_clk -min -add_delay 0.000 [get_ports {Start Relu_En Img_We {Img_Waddr[*]} {Img_Wdata[*]} Kernel_We {Kernel_Windex[*]} {Kernel_Wdata[*]} Out_Rd_En}]
set_output_delay -clock sys_clk -max 1.000 [get_ports {Busy Scan_Done {Out_Data0[*]} {Out_Data1[*]} Out_Valid Out_Full}]
set_output_delay -clock sys_clk -min -add_delay 0.000 [get_ports {Busy Scan_Done {Out_Data0[*]} {Out_Data1[*]} Out_Valid Out_Full}]

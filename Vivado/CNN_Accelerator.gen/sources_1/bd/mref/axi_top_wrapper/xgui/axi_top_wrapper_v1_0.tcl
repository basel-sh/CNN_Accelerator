# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "Acc_W" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "Img_Addrw" -parent ${Page_0}
  ipgui::add_param $IPINST -name "Img_H" -parent ${Page_0}
  ipgui::add_param $IPINST -name "Img_W" -parent ${Page_0}
  ipgui::add_param $IPINST -name "K" -parent ${Page_0}
  ipgui::add_param $IPINST -name "Kernel_W" -parent ${Page_0}
  ipgui::add_param $IPINST -name "Kidxw" -parent ${Page_0}
  ipgui::add_param $IPINST -name "Pixel_W" -parent ${Page_0}


}

proc update_PARAM_VALUE.Acc_W { PARAM_VALUE.Acc_W } {
	# Procedure called to update Acc_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.Acc_W { PARAM_VALUE.Acc_W } {
	# Procedure called to validate Acc_W
	return true
}

proc update_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to update C_S_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.Img_Addrw { PARAM_VALUE.Img_Addrw } {
	# Procedure called to update Img_Addrw when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.Img_Addrw { PARAM_VALUE.Img_Addrw } {
	# Procedure called to validate Img_Addrw
	return true
}

proc update_PARAM_VALUE.Img_H { PARAM_VALUE.Img_H } {
	# Procedure called to update Img_H when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.Img_H { PARAM_VALUE.Img_H } {
	# Procedure called to validate Img_H
	return true
}

proc update_PARAM_VALUE.Img_W { PARAM_VALUE.Img_W } {
	# Procedure called to update Img_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.Img_W { PARAM_VALUE.Img_W } {
	# Procedure called to validate Img_W
	return true
}

proc update_PARAM_VALUE.K { PARAM_VALUE.K } {
	# Procedure called to update K when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.K { PARAM_VALUE.K } {
	# Procedure called to validate K
	return true
}

proc update_PARAM_VALUE.Kernel_W { PARAM_VALUE.Kernel_W } {
	# Procedure called to update Kernel_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.Kernel_W { PARAM_VALUE.Kernel_W } {
	# Procedure called to validate Kernel_W
	return true
}

proc update_PARAM_VALUE.Kidxw { PARAM_VALUE.Kidxw } {
	# Procedure called to update Kidxw when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.Kidxw { PARAM_VALUE.Kidxw } {
	# Procedure called to validate Kidxw
	return true
}

proc update_PARAM_VALUE.Pixel_W { PARAM_VALUE.Pixel_W } {
	# Procedure called to update Pixel_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.Pixel_W { PARAM_VALUE.Pixel_W } {
	# Procedure called to validate Pixel_W
	return true
}


proc update_MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.Pixel_W { MODELPARAM_VALUE.Pixel_W PARAM_VALUE.Pixel_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.Pixel_W}] ${MODELPARAM_VALUE.Pixel_W}
}

proc update_MODELPARAM_VALUE.Kernel_W { MODELPARAM_VALUE.Kernel_W PARAM_VALUE.Kernel_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.Kernel_W}] ${MODELPARAM_VALUE.Kernel_W}
}

proc update_MODELPARAM_VALUE.Acc_W { MODELPARAM_VALUE.Acc_W PARAM_VALUE.Acc_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.Acc_W}] ${MODELPARAM_VALUE.Acc_W}
}

proc update_MODELPARAM_VALUE.Img_W { MODELPARAM_VALUE.Img_W PARAM_VALUE.Img_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.Img_W}] ${MODELPARAM_VALUE.Img_W}
}

proc update_MODELPARAM_VALUE.Img_H { MODELPARAM_VALUE.Img_H PARAM_VALUE.Img_H } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.Img_H}] ${MODELPARAM_VALUE.Img_H}
}

proc update_MODELPARAM_VALUE.K { MODELPARAM_VALUE.K PARAM_VALUE.K } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.K}] ${MODELPARAM_VALUE.K}
}

proc update_MODELPARAM_VALUE.Img_Addrw { MODELPARAM_VALUE.Img_Addrw PARAM_VALUE.Img_Addrw } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.Img_Addrw}] ${MODELPARAM_VALUE.Img_Addrw}
}

proc update_MODELPARAM_VALUE.Kidxw { MODELPARAM_VALUE.Kidxw PARAM_VALUE.Kidxw } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.Kidxw}] ${MODELPARAM_VALUE.Kidxw}
}


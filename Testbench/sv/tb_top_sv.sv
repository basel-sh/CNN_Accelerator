//==============================================================================
// tb_top_sv.sv | Module: tb_top_sv
// QuestaSim top-level: clock/reset generation, RTL/top.v instantiation,
// cnn_if binding (incl. whitebox hierarchical probes into RTL/controller.v),
// and the cnn_env that runs the full Verification_Test_Plan.xlsx regression.
//
// Image/kernel size are elaboration-time overrides (QuestaSim `vsim -g`), so
// FUNC-06 (64x64) / FUNC-07 (K=5) / TIM-03 (8x8) are separate invocations -
// see Testbench/sv/README_QuestaSim.md for the exact commands.
//==============================================================================
`timescale 1ns/1ps
import cnn_pkg::*;

module tb_top_sv #(
    parameter int IMG_W = 32,
    parameter int IMG_H = 32,
    parameter int K     = 3
);
  localparam int PIXEL_W   = cnn_pkg::PIXEL_W;
  localparam int KERNEL_W  = cnn_pkg::KERNEL_W;
  localparam int ACC_W     = cnn_pkg::ACC_W;
  localparam int IMG_ADDRW = $clog2(IMG_W*IMG_H);
  localparam int KIDXW     = $clog2(K*K);

  logic Clk = 0;
  always #5 Clk = ~Clk; // 100 MHz testbench clock (RTL's own operating frequency is set in Vivado/constraints.xdc)

  cnn_if #(
      .PIXEL_W(PIXEL_W), .KERNEL_W(KERNEL_W), .ACC_W(ACC_W),
      .IMG_ADDRW(IMG_ADDRW), .KIDXW(KIDXW)
  ) vif (.Clk(Clk));

  top #(
      .Pixel_W(PIXEL_W), .Kernel_W(KERNEL_W), .Acc_W(ACC_W),
      .Img_W(IMG_W), .Img_H(IMG_H), .K(K),
      .Img_Addrw(IMG_ADDRW), .Kidxw(KIDXW)
  ) dut (
      .Clk           (Clk),
      .Rst_N         (vif.Rst_N),
      .Start         (vif.Start),
      .Relu_En       (vif.Relu_En),
      .Busy          (vif.Busy),
      .Scan_Done     (vif.Scan_Done),
      .Img_We        (vif.Img_We),
      .Img_Waddr     (vif.Img_Waddr),
      .Img_Wdata     (vif.Img_Wdata),
      .Kernel_We     (vif.Kernel_We),
      .Kernel_Windex (vif.Kernel_Windex),
      .Kernel_Wdata  (vif.Kernel_Wdata),
      .Out_Rd_En     (vif.Out_Rd_En),
      .Out_Data      (vif.Out_Data),
      .Out_Valid     (vif.Out_Valid),
      .Out_Full      (vif.Out_Full)
  );

  // ---- whitebox probes: controller.v internals, for TIM-03/04/05 coverage ----
  assign vif.wb_state     = dut.U_Ctrl.State;
  assign vif.wb_raw_valid = dut.U_Ctrl.Raw_Valid;
  assign vif.wb_streaming = dut.U_Ctrl.Streaming;
  assign vif.wb_mem_raddr = dut.U_Ctrl.Mem_Raddr;

  // ---- waveform dump (mirrors Testbench/tb_top.v's flow) ----
  initial begin
    $dumpfile("sim/tb_top_sv.vcd");
    $dumpvars(0, tb_top_sv);
  end

  cnn_env env;
  initial begin
    env = new(vif, vif, IMG_ADDRW, KIDXW, IMG_W, IMG_H, K);
    env.run();
    $display("TB_TOP_SV: regression complete (Img_W=%0d Img_H=%0d K=%0d).", IMG_W, IMG_H, K);
    $finish;
  end

endmodule

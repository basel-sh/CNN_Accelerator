//==============================================================================
// ctrl_unit_test.sv | Module: ctrl_unit_test
// FUNC-09 (unit-level): address sequencing + valid-window gating on a small
// 8x8/K=3 image, with FSM-state functional coverage. Self-checking
// SystemVerilog replacement for Testbench/tb_controller.v.
//==============================================================================
`timescale 1ns/1ps
module ctrl_unit_test;
  localparam int Img_W=8, Img_H=8, K=3, Addrw=6;
  localparam int Total = Img_W*Img_H;

  logic Clk=0, Rst_N=0, Start=0;
  logic [Addrw-1:0] Mem_Raddr;
  logic Streaming, Raw_Valid, Busy, Scan_Done;

  controller #(.Img_W(Img_W), .Img_H(Img_H), .K(K), .Addrw(Addrw)) dut (
      .Clk(Clk), .Rst_N(Rst_N), .Start(Start),
      .Mem_Raddr(Mem_Raddr), .Streaming(Streaming), .Raw_Valid(Raw_Valid),
      .Busy(Busy), .Scan_Done(Scan_Done)
  );

  always #5 Clk = ~Clk;

  int addr_count = 0, valid_count = 0, errors = 0;
  logic [Addrw-1:0] last_addr = 0;
  bit have_last = 0;

  covergroup cg_fsm @(posedge Clk);
    cp_state: coverpoint dut.State { bins idle=(2'd0); bins run=(2'd1); bins done=(2'd2); }
  endgroup
  cg_fsm cg = new();

  always @(posedge Clk) begin
    if (Streaming) begin
      addr_count++;
      if (have_last && (Mem_Raddr != last_addr + 1'b1) && !(last_addr == Total-1)) begin
        $display("[CTRL_UT][FAIL] non-sequential address %0d after %0d", Mem_Raddr, last_addr);
        errors++;
      end
      last_addr = Mem_Raddr;
      have_last = 1;
      if (Raw_Valid) valid_count++;
    end
  end

  initial begin
    $dumpfile("sim/ctrl_unit_test.vcd");
    $dumpvars(0, ctrl_unit_test);

    Rst_N = 0;
    repeat (3) @(posedge Clk);
    @(negedge Clk);
    Rst_N = 1;
    Start = 1;
    @(posedge Clk);
    @(negedge Clk);
    Start = 0;

    repeat (Total + 10) @(posedge Clk);

    $display("FUNC-09: Addr_Count=%0d (expected %0d)", addr_count, Total);
    $display("FUNC-09: Valid_Count=%0d (expected %0d)", valid_count, (Img_W-K+1)*(Img_H-K+1));
    if (addr_count !== Total)                              errors++;
    if (valid_count !== (Img_W-K+1)*(Img_H-K+1))            errors++;

    $display("FUNC-09: FSM state coverage = %0.1f%%", cg.get_coverage());
    if (errors == 0) $display("CTRL_UNIT_TEST: ALL TESTS PASSED");
    else             $display("CTRL_UNIT_TEST: %0d TEST(S) FAILED", errors);
    $finish;
  end
endmodule

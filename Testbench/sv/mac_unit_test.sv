//==============================================================================
// mac_unit_test.sv | Module: mac_unit_test
// FUNC-08 (unit-level): directed arithmetic vectors against RTL/mac.v,
// checking the 2-cycle Valid_In->Valid_Out latency (TIM-07) on every vector.
// Self-checking SystemVerilog replacement for Testbench/tb_mac.v, with
// code coverage (vlog +cover) and a small functional covergroup added.
//==============================================================================
`timescale 1ns/1ps
module mac_unit_test;
  localparam int Pixel_W=8, Kernel_W=8, Acc_W=20, K=3;

  logic Clk = 0, Rst_N = 0, Valid_In = 0;
  logic [K*K*Pixel_W-1:0] Window_Flat;
  logic signed [K*K*Kernel_W-1:0] Kernel_Flat;
  logic Valid_Out;
  logic signed [Acc_W-1:0] Acc_Out;

  int errors = 0, tests_run = 0;

  mac #(.Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W), .K(K)) dut (
      .Clk(Clk), .Rst_N(Rst_N), .Valid_In(Valid_In),
      .Window_Flat(Window_Flat), .Kernel_Flat(Kernel_Flat),
      .Valid_Out(Valid_Out), .Acc_Out(Acc_Out)
  );

  always #5 Clk = ~Clk;

  covergroup cg_mac;
    cp_sign: coverpoint (Acc_Out < 0) ? 2'b10 : (Acc_Out == 0) ? 2'b00 : 2'b01 {
      bins neg = {2'b10}; bins zero = {2'b00}; bins pos = {2'b01};
    }
  endgroup
  cg_mac cg = new();

  task automatic apply_and_check(string name, logic [K*K*Pixel_W-1:0] win,
                                  logic signed [K*K*Kernel_W-1:0] ker,
                                  logic signed [Acc_W-1:0] expected);
    int lat;
    Window_Flat = win; Kernel_Flat = ker; Valid_In = 1;
    // lat counts clock edges elapsed INCLUSIVE of the sampling edge, so it
    // reads directly against mac.v's documented "2-cycle latency" (one edge
    // per pipeline register: Prod_Reg/Valid_D1, then Acc_Out/Valid_Out).
    lat = 0;
    do begin
      @(posedge Clk);
      lat++;
      if (lat == 1) Valid_In = 0; // clear the pulse right after the sampling edge
    end while (!Valid_Out && lat < 10);
    tests_run++;
    if (Acc_Out !== expected) begin
      $display("[MAC_UT][%s] FAIL: expected=%0d got=%0d (latency=%0d)", name, expected, Acc_Out, lat);
      errors++;
    end else if (lat != 2) begin
      $display("[MAC_UT][%s] FAIL (TIM-07): result correct but latency=%0d cycles (expected 2)", name, lat);
      errors++;
    end else begin
      $display("[MAC_UT][%s] PASS: Acc_Out=%0d, latency=2 cycles", name, Acc_Out);
    end
    cg.sample();
  endtask

  initial begin
    $dumpfile("sim/mac_unit_test.vcd");
    $dumpvars(0, mac_unit_test);

    Window_Flat = 0; Kernel_Flat = 0;
    repeat (3) @(posedge Clk);
    Rst_N = 1;

    // FUNC-08.1: identity kernel (center=1) on an all-ones window -> 1
    apply_and_check("FUNC-08.1_identity", {9{8'd1}},
                     {8'sd0,8'sd0,8'sd0,8'sd0,8'sd1,8'sd0,8'sd0,8'sd0,8'sd0}, 20'sd1);

    // FUNC-08.2: sum-of-ones kernel on window 0..8 -> 36
    apply_and_check("FUNC-08.2_sum_ones",
                     {8'd8,8'd7,8'd6,8'd5,8'd4,8'd3,8'd2,8'd1,8'd0}, {9{8'sd1}}, 20'sd36);

    // FUNC-08.3: all -1 kernel on all-255 window -> -2295 (also exercises a negative accumulator path)
    apply_and_check("FUNC-08.3_negative", {9{8'd255}}, {9{8'hFF}}, -20'sd2295);

    // BND-07 (also convenient to re-check here): max positive magnitude, no overflow
    apply_and_check("BND-07_max_pos", {9{8'd255}}, {9{8'sd127}}, 20'sd291465);

    // BND-08: max negative magnitude, no overflow (8'sh80 = -128 two's complement)
    apply_and_check("BND-08_max_neg", {9{8'd255}}, {9{8'sh80}}, -20'sd293760);

    $display("MAC_UNIT_TEST: %0d/%0d vectors passed, functional coverage (sign bins) = %0.1f%%",
              tests_run-errors, tests_run, cg.get_coverage());
    if (errors == 0) $display("MAC_UNIT_TEST: ALL TESTS PASSED");
    else             $display("MAC_UNIT_TEST: %0d TEST(S) FAILED", errors);
    $finish;
  end
endmodule

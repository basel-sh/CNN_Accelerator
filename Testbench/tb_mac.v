//==============================================================================
// tb_mac.v - Phase 9 unit test for RTL/mac.v
// Applies known 3x3 window/kernel vectors and checks Acc_Out against
// hand-computed expected sums.
//==============================================================================
`timescale 1ns/1ps
module tb_mac;
    localparam Pixel_W=8, Kernel_W=8, Acc_W=20, K=3;

    reg Clk=0, Rst_N=0, Valid_In=0;
    reg [K*K*Pixel_W-1:0] Window_Flat;
    reg signed [K*K*Kernel_W-1:0] Kernel_Flat;
    wire Valid_Out;
    wire signed [Acc_W-1:0] Acc_Out;

    integer Errors = 0;

    mac #(.Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W), .K(K)) Dut (
        .Clk(Clk), .Rst_N(Rst_N), .Valid_In(Valid_In),
        .Window_Flat(Window_Flat), .Kernel_Flat(Kernel_Flat),
        .Valid_Out(Valid_Out), .Acc_Out(Acc_Out)
    );

    always #5 Clk = ~Clk;

    task apply_and_check;
        input [K*K*Pixel_W-1:0] Win;
        input signed [K*K*Kernel_W-1:0] Ker;
        input signed [Acc_W-1:0] Expected;
        begin
            Window_Flat = Win;
            Kernel_Flat = Ker;
            Valid_In = 1;
            @(posedge Clk);
            Valid_In = 0;
            @(posedge Clk); // stage 1: products registered
            @(posedge Clk); // stage 2: sum registered, Acc_Out now valid (mac is 2-cycle latency after the timing-fix pipeline)
            if (Acc_Out !== Expected) begin
                $display("FAIL: expected=%0d got=%0d", Expected, Acc_Out);
                Errors = Errors + 1;
            end else begin
                $display("PASS: Acc_Out=%0d", Acc_Out);
            end
        end
    endtask

    initial begin
        $dumpfile("sim/tb_mac.vcd");
        $dumpvars(0, tb_mac);

        Rst_N = 0;
        Window_Flat = 0; Kernel_Flat = 0;
        repeat (3) @(posedge Clk);
        Rst_N = 1;

        // Test 1: all-ones window (pixel=1), identity kernel center=1, rest 0
        apply_and_check({9{8'd1}}, {8'sd0,8'sd0,8'sd0,8'sd0,8'sd1,8'sd0,8'sd0,8'sd0,8'sd0}, 20'sd1);

        // Test 2: window = 0..8, kernel = all ones -> expected = sum(0..8) = 36
        apply_and_check({8'd8,8'd7,8'd6,8'd5,8'd4,8'd3,8'd2,8'd1,8'd0},
                         {9{8'sd1}}, 20'sd36);

        // Test 3: negative kernel coefficients
        // window all 255 (max unsigned), kernel all -1 -> expected = -9*255 = -2295
        apply_and_check({9{8'd255}}, {9{8'hFF}}, -20'sd2295);

        if (Errors == 0)
            $display("TB_MAC: ALL TESTS PASSED");
        else
            $display("TB_MAC: %0d TEST(S) FAILED", Errors);

        $finish;
    end
endmodule

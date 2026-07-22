//==============================================================================
// tb_mac.v - Phase 9 unit test for RTL/mac.v
// Applies a handful of known 3x3 window/kernel vectors and checks acc_out
// against hand-computed expected sums.
//==============================================================================
`timescale 1ns/1ps
module tb_mac;
    localparam PIXEL_W=8, KERNEL_W=8, ACC_W=20, K=3;

    reg clk=0, rst_n=0, valid_in=0;
    reg [K*K*PIXEL_W-1:0] window_flat;
    reg signed [K*K*KERNEL_W-1:0] kernel_flat;
    wire valid_out;
    wire signed [ACC_W-1:0] acc_out;

    integer errors = 0;

    mac #(.PIXEL_W(PIXEL_W), .KERNEL_W(KERNEL_W), .ACC_W(ACC_W), .K(K)) dut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .window_flat(window_flat), .kernel_flat(kernel_flat),
        .valid_out(valid_out), .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    task apply_and_check;
        input [K*K*PIXEL_W-1:0] win;
        input signed [K*K*KERNEL_W-1:0] ker;
        input signed [ACC_W-1:0] expected;
        begin
            window_flat = win;
            kernel_flat = ker;
            valid_in = 1;
            @(posedge clk);
            valid_in = 0;
            @(posedge clk); // wait for registered output
            if (acc_out !== expected) begin
                $display("FAIL: expected=%0d got=%0d", expected, acc_out);
                errors = errors + 1;
            end else begin
                $display("PASS: acc_out=%0d", acc_out);
            end
        end
    endtask

    initial begin
        rst_n = 0;
        window_flat = 0; kernel_flat = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // Test 1: all ones window (pixel=1), identity kernel center=1, rest 0
        // window row-major: all pixel=1 -> 9 bytes of 8'd1
        // kernel: only center (index 4) = 1, rest 0 -> expected = 1
        apply_and_check({9{8'd1}}, {8'sd0,8'sd0,8'sd0,8'sd0,8'sd1,8'sd0,8'sd0,8'sd0,8'sd0}, 20'sd1);

        // Test 2: window = 0..8, kernel = all ones -> expected = sum(0..8)=36
        apply_and_check({8'd8,8'd7,8'd6,8'd5,8'd4,8'd3,8'd2,8'd1,8'd0},
                         {9{8'sd1}}, 20'sd36);

        // Test 3: negative kernel coefficients
        // window all 255 (max unsigned), kernel all -1 (8'hFF two's complement)
        // -> expected = -9*255 = -2295
        apply_and_check({9{8'd255}}, {9{8'hFF}}, -20'sd2295);

        if (errors == 0)
            $display("TB_MAC: ALL TESTS PASSED");
        else
            $display("TB_MAC: %0d TEST(S) FAILED", errors);

        $finish;
    end
endmodule

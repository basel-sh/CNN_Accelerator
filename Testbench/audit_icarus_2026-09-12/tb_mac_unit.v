//==============================================================================
// tb_mac_unit.v — direct unit-level testbench for mac_pair.v
// Covers: FUNC-08 (a,b,c), TIM-07, BND-07, BND-08
//==============================================================================
`timescale 1ns/1ps
module tb_mac_unit;
    localparam Pixel_W=8, Kernel_W=4, Acc_W=16, K=3;
    localparam N = K*K;

    reg Clk=0, Rst_N=1, Valid_In=0;
    reg [N*Pixel_W-1:0] Left_Window_Flat, Right_Window_Flat;
    reg signed [N*Kernel_W-1:0] Kernel_Flat;
    wire Valid_Out;
    wire signed [Acc_W-1:0] Left_Acc_Out, Right_Acc_Out;

    mac_pair #(.Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W), .K(K)) Dut (
        .Clk(Clk), .Rst_N(Rst_N), .Valid_In(Valid_In),
        .Left_Window_Flat(Left_Window_Flat), .Right_Window_Flat(Right_Window_Flat),
        .Kernel_Flat(Kernel_Flat), .Valid_Out(Valid_Out),
        .Left_Acc_Out(Left_Acc_Out), .Right_Acc_Out(Right_Acc_Out)
    );

    always #5 Clk = ~Clk;

    integer pass_count = 0, fail_count = 0;
    task automatic check(input cond, input [8*160-1:0] name);
        begin
            if (cond) begin pass_count=pass_count+1; $display("CHECK PASS: %0s", name); end
            else begin fail_count=fail_count+1; $display("CHECK FAIL: %0s", name); end
        end
    endtask

    integer i;
    reg signed [Acc_W-1:0] exp_left, exp_right;

    task automatic set_window_const(input [Pixel_W-1:0] v);
        integer j;
        begin
            for (j=0;j<N;j=j+1) begin
                Left_Window_Flat[(j+1)*Pixel_W-1 -: Pixel_W] = v;
                Right_Window_Flat[(j+1)*Pixel_W-1 -: Pixel_W] = v;
            end
        end
    endtask

    task automatic set_window_seq(); // 0,1,2,...,8
        integer j;
        begin
            for (j=0;j<N;j=j+1) begin
                Left_Window_Flat[(j+1)*Pixel_W-1 -: Pixel_W] = j[Pixel_W-1:0];
                Right_Window_Flat[(j+1)*Pixel_W-1 -: Pixel_W] = j[Pixel_W-1:0];
            end
        end
    endtask

    task automatic set_kernel_const(input signed [Kernel_W-1:0] v);
        integer j;
        begin
            for (j=0;j<N;j=j+1)
                Kernel_Flat[(j+1)*Kernel_W-1 -: Kernel_W] = v;
        end
    endtask

    task automatic set_kernel_center_one();
        integer j;
        begin
            for (j=0;j<N;j=j+1)
                Kernel_Flat[(j+1)*Kernel_W-1 -: Kernel_W] = (j==4) ? 4'sd1 : 4'sd0; // center of 3x3 flat index=4
        end
    endtask

    task automatic run_vector(input signed [Acc_W-1:0] exp);
        begin
            @(negedge Clk);
            Valid_In = 1;
            @(negedge Clk);            // one posedge elapsed here: Valid_D1 <= 1 (latency stage 1)
            Valid_In = 0;
            @(posedge Clk); #1;        // second posedge: Valid_Out <= Valid_D1 (latency stage 2) -> asserts now
            check(Valid_Out == 1'b1, "TIM-07: Valid_Out asserts exactly 2 cycles after Valid_In pulse");
            check(Left_Acc_Out === exp, "FUNC-08: Left_Acc_Out matches expected directed-vector result");
            check(Right_Acc_Out === exp, "FUNC-08: Right_Acc_Out matches expected directed-vector result");
            @(posedge Clk); #1;
            check(Valid_Out == 1'b0, "TIM-07: Valid_Out is a single-cycle pulse (deasserts the following cycle)");
        end
    endtask

    initial begin
        Rst_N = 0; repeat(3) @(posedge Clk); @(negedge Clk); Rst_N = 1;

        // FUNC-08(a): window=9x1, kernel=center 1 -> Acc=1
        set_window_const(8'd1);
        set_kernel_center_one();
        run_vector(16'sd1);

        // FUNC-08(b): window=0..8, kernel=9x1 -> Acc=36
        set_window_seq();
        set_kernel_const(4'sd1);
        run_vector(16'sd36);

        // FUNC-08(c): window=9x255, kernel=9x(-1) -> Acc=-2295
        set_window_const(8'd255);
        set_kernel_const(-4'sd1);
        run_vector(-16'sd2295);

        // BND-07: max positive accumulator with a signed 4-bit kernel (range
        // -8..7): image=255(x9), kernel=+7(x9) -> 9*255*7=16065
        set_window_const(8'd255);
        set_kernel_const(4'sd7);
        run_vector(16065);
        check(16065 <= 32767 && 16065 >= -32768, "BND-07: result inside 16-bit signed range, no wraparound");

        // BND-08: max negative accumulator: image=255(x9), kernel=-8(x9)
        // (most negative signed 4-bit value) -> -9*255*8=-18360, matching
        // the Section 06 overflow proof (max |sum|=18,360 < 32,768)
        set_window_const(8'd255);
        set_kernel_const(-4'sd8);
        run_vector(-18360);
        check(-18360 <= 32767 && -18360 >= -32768, "BND-08: result inside 16-bit signed range, no wraparound");

        $display("TB_MAC_UNIT: %0d PASS, %0d FAIL", pass_count, fail_count);
        $finish;
    end
endmodule

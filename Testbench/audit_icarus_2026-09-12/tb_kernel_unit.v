//==============================================================================
// tb_kernel_unit.v — direct unit-level testbench for kernel_memory.v
// Covers: BND-11, RST-05, ERR-02
//==============================================================================
`timescale 1ns/1ps
module tb_kernel_unit;
    localparam K=3, Kernel_W=8, Idxw=4;
    localparam N=K*K;

    reg Clk=0, Rst_N=1, We=0;
    reg [Idxw-1:0] Windex=0;
    reg signed [Kernel_W-1:0] Wdata=0;
    wire signed [N*Kernel_W-1:0] Kernel_Flat;

    kernel_memory #(.K(K), .Kernel_W(Kernel_W), .Idxw(Idxw)) Dut (
        .Clk(Clk), .Rst_N(Rst_N), .We(We), .Windex(Windex), .Wdata(Wdata),
        .Kernel_Flat(Kernel_Flat)
    );
    always #5 Clk = ~Clk;

    integer pass_count=0, fail_count=0;
    task automatic check(input cond, input [8*160-1:0] name);
        begin
            if (cond) begin pass_count=pass_count+1; $display("CHECK PASS: %0s", name); end
            else begin fail_count=fail_count+1; $display("CHECK FAIL: %0s", name); end
        end
    endtask

    function signed [Kernel_W-1:0] coeff_at(input integer idx);
        coeff_at = Kernel_Flat[(idx+1)*Kernel_W-1 -: Kernel_W];
    endfunction

    integer i; reg all_others_zero;

    initial begin
        Rst_N = 0; repeat(3) @(posedge Clk); @(negedge Clk); Rst_N = 1;

        // BND-11: program only Windex=8 (K*K-1, last legal slot)
        @(negedge Clk);
        We = 1; Windex = 8; Wdata = 8'sd77;
        @(negedge Clk);
        We = 0;
        check(coeff_at(8) == 8'sd77, "BND-11: coefficient 8 (Windex==max) updates to the written value");
        all_others_zero = 1;
        for (i=0;i<8;i=i+1) if (coeff_at(i) != 0) all_others_zero = 0;
        check(all_others_zero == 1, "BND-11: coefficients 0-7 retain reset value 0, unaffected by the Windex=8 write");

        // ERR-02: Windex driven out of the valid 0..8 range for K=3 (Windex=15, 4'hF)
        @(negedge Clk);
        We = 1; Windex = 4'hF; Wdata = 8'sd99;
        @(negedge Clk);
        We = 0;
        all_others_zero = 1;
        for (i=0;i<9;i=i+1) if (i!=8 && coeff_at(i) != 0) all_others_zero = 0;
        check(coeff_at(8) == 8'sd77, "ERR-02: out-of-range Windex=15 write does not corrupt coefficient 8's prior value");
        check(all_others_zero == 1, "ERR-02: out-of-range Windex=15 write does not corrupt any in-range coefficient (no crash/X)");

        // RST-05: reset clears the programmed kernel
        Rst_N = 0; repeat(3) @(posedge Clk); @(negedge Clk); Rst_N = 1;
        @(negedge Clk);
        all_others_zero = 1;
        for (i=0;i<9;i=i+1) if (coeff_at(i) != 0) all_others_zero = 0;
        check(all_others_zero == 1, "RST-05: synchronous reset zeroes all Coeff[] (kernel cleared, must reprogram after reset)");

        $display("TB_KERNEL_UNIT: %0d PASS, %0d FAIL", pass_count, fail_count);
        $finish;
    end
endmodule

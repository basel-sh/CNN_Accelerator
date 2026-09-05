//==============================================================================
// tb_top.v - Phase 9 system-level testbench for RTL/top.v
//
// 1. Preloads image_memory from Images/input_32x32.mem ($readmemh, unsigned)
// 2. Preloads kernel_memory from Images/kernels/edge_3x3.mem ($readmemh,
//    signed two's-complement hex)
// 3. Asserts Start, streams the whole 32x32 image through the pipeline
// 4. Captures every valid output word (Out_Valid && Out_Rd_En), in order
//    produced, and writes them (two's-complement hex) to sim/rtl_output.mem
// 5. Python/verify.py then compares sim/rtl_output.mem against the golden
//    model's expected output for the automatic PASS/FAIL.
//==============================================================================
`timescale 1ns/1ps
module tb_top;
    localparam Pixel_W=8, Kernel_W=8, Acc_W=20, Img_W=32, Img_H=32, K=3;
    localparam Img_Addrw=10, Kidxw=4, Out_Depth=16, Out_Aw=4;  // matches RTL/top.v's optimized default
    localparam Total_Pix = Img_W*Img_H;
    localparam Num_K = K*K;
    localparam Expected_Outputs = (Img_W-K+1)*(Img_H-K+1);

    reg Clk = 0, Rst_N = 0;
    reg Start = 0, Relu_En = 0;
    reg Img_We = 0;
    reg [Img_Addrw-1:0] Img_Waddr = 0;
    reg [Pixel_W-1:0] Img_Wdata = 0;
    reg Kernel_We = 0;
    reg [Kidxw-1:0] Kernel_Windex = 0;
    reg signed [Kernel_W-1:0] Kernel_Wdata = 0;
    reg Out_Rd_En = 1;   // greedily consume every produced result
    wire signed [Acc_W-1:0] Out_Data;
    wire Out_Valid, Out_Full, Busy, Scan_Done;

    top #(
        .Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W),
        .Img_W(Img_W), .Img_H(Img_H), .K(K),
        .Img_Addrw(Img_Addrw), .Kidxw(Kidxw),
        .Out_Depth(Out_Depth), .Out_Aw(Out_Aw)
    ) Dut (
        .Clk(Clk), .Rst_N(Rst_N), .Start(Start), .Relu_En(Relu_En),
        .Busy(Busy), .Scan_Done(Scan_Done),
        .Img_We(Img_We), .Img_Waddr(Img_Waddr), .Img_Wdata(Img_Wdata),
        .Kernel_We(Kernel_We), .Kernel_Windex(Kernel_Windex), .Kernel_Wdata(Kernel_Wdata),
        .Out_Rd_En(Out_Rd_En), .Out_Data(Out_Data), .Out_Valid(Out_Valid), .Out_Full(Out_Full)
    );

    always #5 Clk = ~Clk;

    reg [Pixel_W-1:0] Image_Stim [0:Total_Pix-1];
    reg signed [Kernel_W-1:0] Kernel_Stim [0:Num_K-1];

    integer I;
    integer Out_File;
    integer Capture_Count;

    initial begin
        $dumpfile("sim/tb_top.vcd");
        $dumpvars(0, tb_top);

        $readmemh("Images/input_32x32.mem", Image_Stim);
        $readmemh("Images/kernels/edge_3x3.mem", Kernel_Stim);

        Out_File = $fopen("sim/rtl_output.mem", "w");
        Capture_Count = 0;

        Rst_N = 0;
        repeat (3) @(posedge Clk);
        @(negedge Clk);
        Rst_N = 1;

        // NOTE: all stimulus changes below happen on @(negedge Clk), well away
        // from the DUT's own @(posedge Clk) logic, to avoid a classic
        // testbench/DUT same-edge race on blocking-assigned stimulus signals
        // (see Documentation/VerificationResults.md).

        // --- preload image memory ---
        for (I = 0; I < Total_Pix; I = I + 1) begin
            Img_We    = 1;
            Img_Waddr = I[Img_Addrw-1:0];
            Img_Wdata = Image_Stim[I];
            @(posedge Clk);
            @(negedge Clk);
        end
        Img_We = 0;

        // --- preload kernel memory ---
        for (I = 0; I < Num_K; I = I + 1) begin
            Kernel_We    = 1;
            Kernel_Windex = I[Kidxw-1:0];
            Kernel_Wdata  = Kernel_Stim[I];
            @(posedge Clk);
            @(negedge Clk);
        end
        Kernel_We = 0;

        // --- run convolution ---
        Start = 1;
        @(posedge Clk);
        @(negedge Clk);
        Start = 0;

        // Run long enough for Total_Pix streaming cycles + pipeline drain + margin
        repeat (Total_Pix + 50) @(posedge Clk);

        $display("TB_TOP: captured %0d outputs (expected %0d)", Capture_Count, Expected_Outputs);
        if (Capture_Count == Expected_Outputs)
            $display("TB_TOP: OUTPUT COUNT MATCHES EXPECTATION");
        else
            $display("TB_TOP: *** OUTPUT COUNT MISMATCH ***");

        $fclose(Out_File);
        $finish;
    end

    // capture every produced (and consumed) result, in FIFO order
    always @(posedge Clk) begin
        if (Rst_N && Out_Valid && Out_Rd_En) begin
            $fwrite(Out_File, "%05x\n", Out_Data & {Acc_W{1'b1}});
            Capture_Count = Capture_Count + 1;
        end
    end
endmodule

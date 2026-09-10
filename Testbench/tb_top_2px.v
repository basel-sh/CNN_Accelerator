//==============================================================================
// tb_top_2px.v | System-level verification for top_2px
//
// Writes both lanes in raster order: lane0 then lane1. For 32x32/K=3 this
// produces the same 900-value stream expected by Python/verify.py.
//
// Optional ReLU test:
//   launch_simulation ... -testplusarg RELU=1
// The default is ReLU disabled, matching the baseline verification.
//==============================================================================
`timescale 1ns/1ps
module tb_top_2px;
    localparam Pixel_W=8, Kernel_W=8, Acc_W=20, Img_W=32, Img_H=32, K=3;
    localparam Img_Addrw=10, Kidxw=4;
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
    reg Out_Rd_En = 1;

    wire signed [Acc_W-1:0] Out_Data0, Out_Data1;
    wire Out_Valid, Out_Full, Busy, Scan_Done;

    top_2px #(
        .Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W),
        .Img_W(Img_W), .Img_H(Img_H), .K(K),
        .Img_Addrw(Img_Addrw), .Kidxw(Kidxw)
    ) Dut (
        .Clk(Clk), .Rst_N(Rst_N), .Start(Start), .Relu_En(Relu_En),
        .Busy(Busy), .Scan_Done(Scan_Done),
        .Img_We(Img_We), .Img_Waddr(Img_Waddr), .Img_Wdata(Img_Wdata),
        .Kernel_We(Kernel_We), .Kernel_Windex(Kernel_Windex), .Kernel_Wdata(Kernel_Wdata),
        .Out_Rd_En(Out_Rd_En), .Out_Data0(Out_Data0), .Out_Data1(Out_Data1),
        .Out_Valid(Out_Valid), .Out_Full(Out_Full)
    );

    always #5 Clk = ~Clk;

    reg [Pixel_W-1:0] Image_Stim [0:Total_Pix-1];
    reg signed [Kernel_W-1:0] Kernel_Stim [0:Num_K-1];
    integer I;
    integer Out_File;
    integer Capture_Count;
    integer Pair_Count;
    integer Relu_Mode;

    initial begin
        Relu_Mode = 0;
        if ($value$plusargs("RELU=%d", Relu_Mode)) begin
            Relu_En = (Relu_Mode != 0);
        end
        $display("TB_TOP_2PX: ReLU=%0d", Relu_En);

        $dumpfile("sim/tb_top_2px.vcd");
        $dumpvars(0, tb_top_2px);

        $readmemh("Images/input_32x32.mem", Image_Stim);
        $readmemh("Images/kernels/edge_3x3.mem", Kernel_Stim);

        Out_File = $fopen("sim/rtl_output_2px.mem", "w");
        Capture_Count = 0;
        Pair_Count = 0;

        Rst_N = 0;
        repeat (3) @(posedge Clk);
        @(negedge Clk);
        Rst_N = 1;

        for (I = 0; I < Total_Pix; I = I + 1) begin
            Img_We    = 1;
            Img_Waddr = I[Img_Addrw-1:0];
            Img_Wdata = Image_Stim[I];
            @(posedge Clk);
            @(negedge Clk);
        end
        Img_We = 0;

        for (I = 0; I < Num_K; I = I + 1) begin
            Kernel_We     = 1;
            Kernel_Windex = I[Kidxw-1:0];
            Kernel_Wdata  = Kernel_Stim[I];
            @(posedge Clk);
            @(negedge Clk);
        end
        Kernel_We = 0;

        Start = 1;
        @(posedge Clk);
        @(negedge Clk);
        Start = 0;

        repeat (Total_Pix + 80) @(posedge Clk);

        $display("TB_TOP_2PX: captured %0d outputs from %0d pairs (expected %0d outputs)",
                 Capture_Count, Pair_Count, Expected_Outputs);
        if (Capture_Count == Expected_Outputs)
            $display("TB_TOP_2PX: OUTPUT COUNT MATCHES EXPECTATION");
        else
            $display("TB_TOP_2PX: *** OUTPUT COUNT MISMATCH ***");

        $fclose(Out_File);
        $finish;
    end

    always @(posedge Clk) begin
        if (Rst_N && Out_Valid && Out_Rd_En) begin
            $fwrite(Out_File, "%05x\n", Out_Data0 & {Acc_W{1'b1}});
            $fwrite(Out_File, "%05x\n", Out_Data1 & {Acc_W{1'b1}});
            Capture_Count = Capture_Count + 2;
            Pair_Count = Pair_Count + 1;
        end
    end
endmodule

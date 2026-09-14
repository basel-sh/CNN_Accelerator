//==============================================================================
// tb_b2b04.v — B2B-04: 3 consecutive frames back-to-back, consumer always
// draining (Out_Rd_En held at 1 throughout). Dumps all 3 for golden compare
// and checks Out_Full never asserts.
//==============================================================================
`timescale 1ns/1ps
module tb_b2b04;
    localparam Pixel_W=8, Kernel_W=4, Acc_W=16, Img_W=8, Img_H=8, K=3, Addrw=6, Kidxw=4;
    localparam Total_Pix=Img_W*Img_H, Num_K=K*K;

    reg Clk=0, Rst_N=0, Start=0, Relu_En=0;
    reg Img_We=0; reg [Addrw-1:0] Img_Waddr=0; reg [Pixel_W-1:0] Img_Wdata=0;
    reg Kernel_We=0; reg [Kidxw-1:0] Kernel_Windex=0; reg signed [Kernel_W-1:0] Kernel_Wdata=0;
    reg Out_Rd_En=1;
    wire signed [Acc_W-1:0] Out_Data0, Out_Data1;
    wire Out_Valid, Out_Full, Busy, Scan_Done;

    top_2px #(.Pixel_W(Pixel_W),.Kernel_W(Kernel_W),.Acc_W(Acc_W),.Img_W(Img_W),.Img_H(Img_H),
              .K(K),.Img_Addrw(Addrw),.Kidxw(Kidxw)) Dut (
        .Clk(Clk),.Rst_N(Rst_N),.Start(Start),.Relu_En(Relu_En),.Busy(Busy),.Scan_Done(Scan_Done),
        .Img_We(Img_We),.Img_Waddr(Img_Waddr),.Img_Wdata(Img_Wdata),
        .Kernel_We(Kernel_We),.Kernel_Windex(Kernel_Windex),.Kernel_Wdata(Kernel_Wdata),
        .Out_Rd_En(Out_Rd_En),.Out_Data0(Out_Data0),.Out_Data1(Out_Data1),
        .Out_Valid(Out_Valid),.Out_Full(Out_Full)
    );
    always #5 Clk = ~Clk;

    reg [Pixel_W-1:0] Image_Stim [0:Total_Pix-1];
    reg signed [Kernel_W-1:0] Kernel_K [0:Num_K-1];
    integer I, Out_File, Capture_Count;
    integer full_seen = 0;

    always @(posedge Clk) if (Out_Full) full_seen = full_seen + 1;

    task automatic run_frame(input integer idx);
        reg [8*32-1:0] fname;
        begin
            case (idx)
                0: fname = "sim/b2b04_run0.mem";
                1: fname = "sim/b2b04_run1.mem";
                default: fname = "sim/b2b04_run2.mem";
            endcase
            Out_File = $fopen(fname,"w"); Capture_Count=0;
            Start=1; @(posedge Clk); @(negedge Clk); Start=0;
            wait(Scan_Done); repeat(30) @(posedge Clk); @(negedge Clk);
            $fclose(Out_File);
            $display("B2B04_RUN%0d: captured %0d", idx, Capture_Count);
        end
    endtask

    initial begin
        $readmemh("mem/b2b04_image.mem", Image_Stim);
        $readmemh("mem/b2b04_kernel.mem", Kernel_K);

        Rst_N=0; repeat(3) @(posedge Clk); @(negedge Clk); Rst_N=1;
        for (I=0;I<Total_Pix;I=I+1) begin
            Img_We=1; Img_Waddr=I[Addrw-1:0]; Img_Wdata=Image_Stim[I];
            @(posedge Clk); @(negedge Clk);
        end
        Img_We=0;
        for (I=0;I<Num_K;I=I+1) begin
            Kernel_We=1; Kernel_Windex=I[Kidxw-1:0]; Kernel_Wdata=Kernel_K[I];
            @(posedge Clk); @(negedge Clk);
        end
        Kernel_We=0;

        run_frame(0);
        run_frame(1);
        run_frame(2);

        $display("B2B04_FULL_ASSERTED_CYCLES: %0d", full_seen);
        $finish;
    end

    always @(posedge Clk) begin
        if (Rst_N && Out_Valid && Out_Rd_En) begin
            $fwrite(Out_File, "%05x\n", Out_Data0 & {Acc_W{1'b1}});
            $fwrite(Out_File, "%05x\n", Out_Data1 & {Acc_W{1'b1}});
            Capture_Count = Capture_Count + 2;
        end
    end
endmodule

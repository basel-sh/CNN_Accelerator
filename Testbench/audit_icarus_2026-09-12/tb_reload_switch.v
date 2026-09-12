//==============================================================================
// tb_reload_switch.v — FUNC-04 / B2B-03: kernel reprogrammed between two
// back-to-back runs (no reset), same image both runs. Dumps run1/run2
// outputs separately for a Python golden-model compare against kernel A
// and kernel B respectively.
//==============================================================================
`timescale 1ns/1ps
module tb_reload_switch;
    localparam Pixel_W=8, Kernel_W=8, Acc_W=20, Img_W=8, Img_H=8, K=3, Addrw=6, Kidxw=4;
    localparam Total_Pix=Img_W*Img_H, Num_K=K*K;
    localparam Expected_Outputs=(Img_W-K+1)*(Img_H-K+1);

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
    reg signed [Kernel_W-1:0] Kernel_A [0:Num_K-1];
    reg signed [Kernel_W-1:0] Kernel_B [0:Num_K-1];
    integer I, Out_File, Capture_Count;

    task automatic load_image;
        begin
            for (I=0;I<Total_Pix;I=I+1) begin
                Img_We=1; Img_Waddr=I[Addrw-1:0]; Img_Wdata=Image_Stim[I];
                @(posedge Clk); @(negedge Clk);
            end
            Img_We=0;
        end
    endtask

    task automatic load_kernel(input integer which);
        begin
            for (I=0;I<Num_K;I=I+1) begin
                Kernel_We=1; Kernel_Windex=I[Kidxw-1:0];
                Kernel_Wdata = (which==0) ? Kernel_A[I] : Kernel_B[I];
                @(posedge Clk); @(negedge Clk);
            end
            Kernel_We=0;
        end
    endtask

    initial begin
        $readmemh("mem/reload_image.mem", Image_Stim);
        $readmemh("mem/reload_kernelA.mem", Kernel_A);
        $readmemh("mem/reload_kernelB.mem", Kernel_B);

        Rst_N=0; repeat(3) @(posedge Clk); @(negedge Clk); Rst_N=1;
        load_image();
        load_kernel(0); // kernel A

        Out_File = $fopen("sim/reload_run1.mem","w"); Capture_Count=0;
        Start=1; @(posedge Clk); @(negedge Clk); Start=0;
        wait(Scan_Done);
        repeat(30) @(posedge Clk);
        @(negedge Clk);
        $fclose(Out_File);
        $display("RUN1: captured %0d (expected %0d)", Capture_Count, Expected_Outputs);

        // Reprogram to kernel B, NO reset, start run 2 immediately.
        load_kernel(1);
        Out_File = $fopen("sim/reload_run2.mem","w"); Capture_Count=0;
        Start=1; @(posedge Clk); @(negedge Clk); Start=0;
        wait(Scan_Done);
        repeat(30) @(posedge Clk);
        @(negedge Clk);
        $fclose(Out_File);
        $display("RUN2: captured %0d (expected %0d)", Capture_Count, Expected_Outputs);
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

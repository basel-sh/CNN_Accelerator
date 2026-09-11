//==============================================================================
// top_2px.v | Aggressive true 2-output/cycle convolution accelerator
//
// Separate experiment; RTL/top.v is untouched. Two adjacent input pixels are
// read every clock, two adjacent windows are generated every clock, and the
// overlap-aware MAC produces both convolution results together.
//==============================================================================
module top_2px #(
    parameter Pixel_W   = 8,
    parameter Kernel_W  = 8,
    parameter Acc_W     = 20,
    parameter Img_W     = 32,
    parameter Img_H     = 32,
    parameter K         = 3,
    parameter Img_Addrw = 10,
    parameter Kidxw     = 4
)(
    input  wire                         Clk,
    input  wire                         Rst_N,
    input  wire                         Start,
    input  wire                         Relu_En,
    output wire                         Busy,
    output wire                         Scan_Done,
    input  wire                         Img_We,
    input  wire [Img_Addrw-1:0]         Img_Waddr,
    input  wire [Pixel_W-1:0]           Img_Wdata,
    input  wire                         Kernel_We,
    input  wire [Kidxw-1:0]             Kernel_Windex,
    input  wire signed [Kernel_W-1:0]   Kernel_Wdata,
    input  wire                         Out_Rd_En,
    output wire signed [Acc_W-1:0]      Out_Data0,
    output wire signed [Acc_W-1:0]      Out_Data1,
    output wire                         Out_Valid,
    output wire                         Out_Full
);
    wire [Img_Addrw-1:0] Mem_Raddr0, Mem_Raddr1;
    wire Streaming, Pair_Valid_Raw;

    controller_2px #(
        .Img_W(Img_W), .Img_H(Img_H), .K(K), .Addrw(Img_Addrw)
    ) U_Ctrl (
        .Clk(Clk), .Rst_N(Rst_N), .Start(Start),
        .Mem_Raddr0(Mem_Raddr0), .Mem_Raddr1(Mem_Raddr1),
        .Streaming(Streaming), .Pair_Valid(Pair_Valid_Raw),
        .Busy(Busy), .Scan_Done(Scan_Done)
    );

    wire [Pixel_W-1:0] Pixel_In0, Pixel_In1;
    image_memory_2px #(
        .Pixel_W(Pixel_W), .Img_W(Img_W), .Img_H(Img_H), .Addrw(Img_Addrw)
    ) U_Img_Mem (
        .Clk(Clk), .We(Img_We), .Waddr(Img_Waddr), .Wdata(Img_Wdata),
        .Raddr0(Mem_Raddr0), .Raddr1(Mem_Raddr1),
        .Rdata0(Pixel_In0), .Rdata1(Pixel_In1)
    );

    wire signed [K*K*Kernel_W-1:0] Kernel_Flat;
    kernel_memory #(.K(K), .Kernel_W(Kernel_W), .Idxw(Kidxw)) U_Kernel_Mem (
        .Clk(Clk), .Rst_N(Rst_N), .We(Kernel_We),
        .Windex(Kernel_Windex), .Wdata(Kernel_Wdata), .Kernel_Flat(Kernel_Flat)
    );

    // Same alignment principle as the verified baseline, but the stream unit
    // is now a two-pixel block rather than one pixel.
    reg Shift_En_D1;
    reg Pair_Valid_D1;
    reg Pair_Valid_D2;
    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Shift_En_D1   <= 1'b0;
            Pair_Valid_D1 <= 1'b0;
            Pair_Valid_D2 <= 1'b0;
        end else begin
            Shift_En_D1   <= Streaming;
            Pair_Valid_D1 <= Pair_Valid_Raw;
            Pair_Valid_D2 <= Pair_Valid_D1;
        end
    end

    wire [K*Pixel_W-1:0] Row_Taps_A_Flat, Row_Taps_B_Flat;
    line_buffer_2px #(.Pixel_W(Pixel_W), .Img_W(Img_W), .K(K)) U_Line_Buf (
        .Clk(Clk), .Rst_N(Rst_N), .Shift_En(Shift_En_D1),
        .Pixel_A(Pixel_In0), .Pixel_B(Pixel_In1),
        .Row_Taps_A_Flat(Row_Taps_A_Flat), .Row_Taps_B_Flat(Row_Taps_B_Flat)
    );

    wire [K*K*Pixel_W-1:0] Window_A_Flat, Window_B_Flat;
    window_generator_2px #(.Pixel_W(Pixel_W), .K(K)) U_Win_Gen (
        .Clk(Clk), .Rst_N(Rst_N), .Shift_En(Shift_En_D1),
        .Row_Taps_A_Flat(Row_Taps_A_Flat), .Row_Taps_B_Flat(Row_Taps_B_Flat),
        .Window_A_Flat(Window_A_Flat), .Window_B_Flat(Window_B_Flat)
    );

    wire Mac_Valid_Out;
    wire signed [Acc_W-1:0] Mac_Out0, Mac_Out1;
    mac_pair #(.Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W), .K(K)) U_Mac_Pair (
        .Clk(Clk), .Rst_N(Rst_N), .Valid_In(Pair_Valid_D2),
        .Left_Window_Flat(Window_A_Flat), .Right_Window_Flat(Window_B_Flat),
        .Kernel_Flat(Kernel_Flat), .Valid_Out(Mac_Valid_Out),
        .Left_Acc_Out(Mac_Out0), .Right_Acc_Out(Mac_Out1)
    );

    assign Out_Valid = Mac_Valid_Out && Out_Rd_En;
    assign Out_Full  = 1'b0;
    assign Out_Data0 = (Relu_En && Mac_Out0[Acc_W-1]) ? {Acc_W{1'b0}} : Mac_Out0;
    assign Out_Data1 = (Relu_En && Mac_Out1[Acc_W-1]) ? {Acc_W{1'b0}} : Mac_Out1;
endmodule

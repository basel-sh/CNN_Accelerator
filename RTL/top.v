//==============================================================================
// top.v | Module: top | Phase 8 - Top Integration
// Wires image_memory, kernel_memory, controller, line_buffer,
// window_generator, mac, and output_buffer into the complete NxN convolution
// accelerator. Also performs the small pipeline-alignment shifting (the
// image-memory read register and the window-generator register each add one
// cycle) needed to keep the "valid window" tag in lockstep with the data as
// it flows through the datapath. mac.v is self-contained: it pairs its own
// Valid_Out with Acc_Out regardless of its internal latency (2 cycles, after
// the timing-closure pipeline fix), so top.v does not need to track that
// latency explicitly.
//==============================================================================
module top #(
    parameter Pixel_W  = 8,
    parameter Kernel_W = 8,
    parameter Acc_W    = 20,
    parameter Img_W    = 32,
    parameter Img_H    = 32,
    parameter K        = 3,
    parameter Img_Addrw = 10,        // ceil(log2(Img_W*Img_H))
    parameter Kidxw      = 4,        // ceil(log2(K*K))
    parameter Out_Depth  = 16,   // right-sized: testbench/host drains Out_Rd_En every cycle, no full-frame buffering needed (was 1024 -> forced ~20k register-based FIFO, see Documentation/OptimizationLog.md)
    parameter Out_Aw     = 4
)(
    input  wire                        Clk,
    input  wire                        Rst_N,

    // control
    input  wire                        Start,
    input  wire                        Relu_En,
    output wire                        Busy,
    output wire                        Scan_Done,

    // image load interface (host/testbench preloads image_memory)
    input  wire                        Img_We,
    input  wire [Img_Addrw-1:0]        Img_Waddr,
    input  wire [Pixel_W-1:0]          Img_Wdata,

    // kernel load interface (host/testbench preloads kernel_memory)
    input  wire                        Kernel_We,
    input  wire [Kidxw-1:0]            Kernel_Windex,
    input  wire signed [Kernel_W-1:0]  Kernel_Wdata,

    // result stream out
    input  wire                        Out_Rd_En,
    output wire signed [Acc_W-1:0]     Out_Data,
    output wire                        Out_Valid,
    output wire                        Out_Full
);

    // ---------------- controller ----------------
    wire [Img_Addrw-1:0] Mem_Raddr;
    wire                 Streaming;
    wire                 Raw_Valid;

    controller #(
        .Img_W(Img_W), .Img_H(Img_H), .K(K), .Addrw(Img_Addrw)
    ) U_Ctrl (
        .Clk(Clk), .Rst_N(Rst_N), .Start(Start),
        .Mem_Raddr(Mem_Raddr), .Streaming(Streaming), .Raw_Valid(Raw_Valid),
        .Busy(Busy), .Scan_Done(Scan_Done)
    );

    // ---------------- image memory ----------------
    wire [Pixel_W-1:0] Pixel_In;
    image_memory #(
        .Pixel_W(Pixel_W), .Img_W(Img_W), .Img_H(Img_H), .Addrw(Img_Addrw)
    ) U_Img_Mem (
        .Clk(Clk), .We(Img_We), .Waddr(Img_Waddr), .Wdata(Img_Wdata),
        .Raddr(Mem_Raddr), .Rdata(Pixel_In)
    );

    // ---------------- kernel memory ----------------
    wire signed [K*K*Kernel_W-1:0] Kernel_Flat;
    kernel_memory #(
        .K(K), .Kernel_W(Kernel_W), .Idxw(Kidxw)
    ) U_Kernel_Mem (
        .Clk(Clk), .Rst_N(Rst_N), .We(Kernel_We),
        .Windex(Kernel_Windex), .Wdata(Kernel_Wdata),
        .Kernel_Flat(Kernel_Flat)
    );

    // ---------------- pipeline-alignment stage 1: pixel becomes valid ----------------
    reg Shift_En_D1;
    reg Valid_Tag_D1;
    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Shift_En_D1  <= 1'b0;
            Valid_Tag_D1 <= 1'b0;
        end else begin
            Shift_En_D1  <= Streaming;
            Valid_Tag_D1 <= Raw_Valid;
        end
    end

    // ---------------- line buffer ----------------
    wire [K*Pixel_W-1:0] Row_Taps_Flat;
    line_buffer #(
        .Pixel_W(Pixel_W), .Img_W(Img_W), .K(K)
    ) U_Line_Buf (
        .Clk(Clk), .Rst_N(Rst_N),
        .Shift_En(Shift_En_D1), .Pixel_In(Pixel_In),
        .Row_Taps_Flat(Row_Taps_Flat)
    );

    // ---------------- window generator ----------------
    wire [K*K*Pixel_W-1:0] Window_Flat;
    window_generator #(
        .Pixel_W(Pixel_W), .K(K)
    ) U_Win_Gen (
        .Clk(Clk), .Rst_N(Rst_N),
        .Shift_En(Shift_En_D1), .Row_Taps_Flat(Row_Taps_Flat),
        .Window_Flat(Window_Flat)
    );

    // ---------------- pipeline-alignment stage 2: window becomes valid ----------------
    reg Valid_Tag_D2;
    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N)
            Valid_Tag_D2 <= 1'b0;
        else
            Valid_Tag_D2 <= Valid_Tag_D1;
    end

    // ---------------- MAC ----------------
    wire Mac_Valid_Out;
    wire signed [Acc_W-1:0] Mac_Acc_Out;
    mac #(
        .Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W), .K(K)
    ) U_Mac (
        .Clk(Clk), .Rst_N(Rst_N),
        .Valid_In(Valid_Tag_D2), .Window_Flat(Window_Flat), .Kernel_Flat(Kernel_Flat),
        .Valid_Out(Mac_Valid_Out), .Acc_Out(Mac_Acc_Out)
    );

    // ---------------- output buffer ----------------
    output_buffer #(
        .Acc_W(Acc_W), .Depth(Out_Depth), .Aw(Out_Aw)
    ) U_Out_Buf (
        .Clk(Clk), .Rst_N(Rst_N), .Relu_En(Relu_En),
        .Valid_In(Mac_Valid_Out), .Data_In(Mac_Acc_Out),
        .Rd_En(Out_Rd_En), .Data_Out(Out_Data), .Out_Valid(Out_Valid), .Full(Out_Full)
    );

endmodule

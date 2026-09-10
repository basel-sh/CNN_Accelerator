//==============================================================================
// image_memory_2px.v | Dual-read image memory for the 2px/cycle experiment
//
// The image is preloaded through the single write port before Start. During
// processing both read ports are used simultaneously, so two adjacent pixels
// are delivered per clock. This is a genuine bandwidth increase, not merely
// two outputs produced on alternate cycles.
//==============================================================================
module image_memory_2px #(
    parameter Pixel_W = 8,
    parameter Img_W  = 32,
    parameter Img_H  = 32,
    parameter Addrw  = $clog2(Img_W*Img_H)
)(
    input  wire                   Clk,
    input  wire                   We,
    input  wire [Addrw-1:0]       Waddr,
    input  wire [Pixel_W-1:0]     Wdata,
    input  wire [Addrw-1:0]       Raddr0,
    input  wire [Addrw-1:0]       Raddr1,
    output reg  [Pixel_W-1:0]     Rdata0,
    output reg  [Pixel_W-1:0]     Rdata1
);
    (* ram_style = "block" *) reg [Pixel_W-1:0] Mem [0:Img_W*Img_H-1];

    // Port A: write during preload and read port 0 during processing.
    always @(posedge Clk) begin
        if (We)
            Mem[Waddr] <= Wdata;
        Rdata0 <= Mem[Raddr0];
    end

    // Port B: independent read. During processing this is the second memory
    // port. We deliberately do not write through this port.
    always @(posedge Clk) begin
        Rdata1 <= Mem[Raddr1];
    end
endmodule

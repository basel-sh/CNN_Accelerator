//==============================================================================
// image_memory.v | Module: image_memory | Phase 3 - Memory Architecture
// Stores the unsigned input image (default 32x32, Pixel_W-bit). Preloaded via
// the write port (host/testbench); read by controller.v in raster-scan order.
//==============================================================================
module image_memory #(
    parameter Pixel_W = 8,
    parameter Img_W    = 32,
    parameter Img_H    = 32,
    parameter Addrw     = $clog2(Img_W * Img_H)
)(
    input  wire                  Clk,
    input  wire                  We,
    input  wire [Addrw-1:0]      Waddr,
    input  wire [Pixel_W-1:0]    Wdata,
    input  wire [Addrw-1:0]      Raddr,
    output wire [Pixel_W-1:0]    Rdata
);
    ram #(
        .Width(Pixel_W),
        .Depth(Img_W * Img_H),
        .Addrw(Addrw)
    ) U_Ram (
        .Clk          (Clk),
        .Write_Enable (We),
        .Write_Addr   (Waddr),
        .Write_Data   (Wdata),
        .Read_Addr    (Raddr),
        .Read_Data    (Rdata)
    );
endmodule

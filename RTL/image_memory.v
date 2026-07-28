//==============================================================================
// File   : image_memory.v  |  Module: image_memory  |  Phase 3 - Memory Arch.
// Stores the unsigned input image (default 32x32, PIXEL_W-bit). Preloaded via
// the write port (host/testbench); read by controller.v in raster-scan order.
//==============================================================================
module image_memory #(
    parameter PIXEL_W = 8,
    parameter IMG_W    = 32,
    parameter IMG_H    = 32,
    parameter ADDRW    = $clog2(IMG_W * IMG_H)          // ceil(log2(IMG_W*IMG_H))
)(
    input  wire                  clk,
    input  wire                  we,
    input  wire [ADDRW-1:0]      waddr,
    input  wire [PIXEL_W-1:0]    wdata,
    input  wire [ADDRW-1:0]      raddr,
    output wire [PIXEL_W-1:0]    rdata
);
    ram #(
        .WIDTH(PIXEL_W),
        .DEPTH(IMG_W * IMG_H),
        .ADDRW(ADDRW)
    ) u_ram (
        .clk   (clk),
        .WriteEnable (we),
        .WriteAddr (waddr),
        .WriteData (wdata),
        .ReadAddr (raddr),
        .ReadData (rdata)
    );
endmodule

//==============================================================================
// axi_top_wrapper.v | Module: axi_top_wrapper | Phase 13 - Real-board (AXI) integration
// AXI4-Lite slave wrapping `top` so the CNN accelerator can be driven by the
// Zynq PS (ARM core) over the AXI interconnect instead of raw board pins.
// This is what removes the NSTD-1/UCIO-1 DRC errors for a real-board build:
// once this wrapper sits inside a Zynq block design, the only signals left
// as true top-level ports are Clk/Rst_N (supplied internally by the PS7's
// FCLK_CLK0/FCLK_RESET0_N - no external pin at all) plus DDR/FIXED_IO, both
// auto-constrained by the Pynq-Z2 board preset - not all 61 of top's raw
// ports.
//
// Register map (byte offsets, 32-bit AXI-Lite, word aligned):
//   0x00 CTRL         [W]  bit0=Start (self-clearing pulse), bit1=Relu_En (sticky)
//                     [R]  bit1=Relu_En readback
//   0x04 STATUS       [R]  bit0=Busy, bit1=Scan_Done, bit2=Out_Full, bit3=Out_Valid
//   0x08 IMG_WADDR    [W]  [9:0] Img_Waddr (latched, no side effect)
//                     [R]  readback
//   0x0C IMG_WDATA    [W]  [7:0] Img_Wdata - the WRITE itself pulses Img_We
//                          for one cycle at the address last written to
//                          IMG_WADDR
//   0x10 KERNEL_WINDEX[W]  [3:0] Kernel_Windex (latched, no side effect)
//                     [R]  readback
//   0x14 KERNEL_WDATA [W]  [7:0] Kernel_Wdata (signed) - the WRITE pulses
//                          Kernel_We for one cycle at the index last written
//   0x18 OUT_DATA     [R]  [19:0] Out_Data sign-extended to 32 bits - the
//                          READ itself pulses Out_Rd_En for one cycle (pops
//                          the output FIFO). Poll STATUS.Out_Valid first.
//
// Driver sequence (software):
//   1) write KERNEL_WINDEX, write KERNEL_WDATA  (x9, for a 3x3 kernel)
//   2) write IMG_WADDR, write IMG_WDATA          (xImg_W*Img_H, per pixel)
//   3) write CTRL.Relu_En if desired, then write CTRL.Start=1
//   4) poll STATUS.Busy until 0 (or just poll Out_Valid as results stream)
//   5) while STATUS.Out_Valid: read OUT_DATA, store it (each read pops one)
//
// Verified so far: compiles and elaborates cleanly (Icarus Verilog), and a
// smoke-test AXI write/read sequence completes without deadlock. NOT yet
// run through a full AXI VIP / directed testbench - do that before trusting
// this on hardware.
//==============================================================================
`timescale 1ns / 1ps

module axi_top_wrapper #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5,

    parameter Pixel_W   = 8,
    parameter Kernel_W  = 8,
    parameter Acc_W     = 20,
    parameter Img_W     = 32,
    parameter Img_H     = 32,
    parameter K         = 3,
    parameter Img_Addrw = 10,
    parameter Kidxw     = 4
)(
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                        s_axi_awprot,
    input  wire                              s_axi_awvalid,
    output reg                               s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output reg                               s_axi_wready,

    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                        s_axi_arprot,
    input  wire                              s_axi_arvalid,
    output reg                               s_axi_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready
);

    localparam ADDR_LSB = 2; // 32-bit registers -> word index starts at bit 2

    // ---- internal register file ----
    reg                        Relu_En_r;
    reg  [Img_Addrw-1:0]       Img_Waddr_r;
    reg  [Kidxw-1:0]           Kernel_Windex_r;

    reg                        Start_pulse;
    reg                        Img_We_pulse;
    reg  [Pixel_W-1:0]         Img_Wdata_r;
    reg                        Kernel_We_pulse;
    reg  signed [Kernel_W-1:0] Kernel_Wdata_r;
    reg                        Out_Rd_En_pulse;

    wire                        Busy_w, Scan_Done_w, Out_Full_w, Out_Valid_w;
    wire signed [Acc_W-1:0]     Out_Data_w;

    // ---- AXI write address channel ----
    reg aw_en;
    wire axi_wr_en = s_axi_wready && s_axi_wvalid && s_axi_awready && s_axi_awvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_l;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            aw_en         <= 1'b1;
            axi_awaddr_l  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
            s_axi_awready <= 1'b1;
            aw_en         <= 1'b0;
            axi_awaddr_l  <= s_axi_awaddr;
        end else if (s_axi_bready && s_axi_bvalid) begin
            aw_en         <= 1'b1;
            s_axi_awready <= 1'b0;
        end else begin
            s_axi_awready <= 1'b0;
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_wready <= 1'b0;
        else if (~s_axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en)
            s_axi_wready <= 1'b1;
        else
            s_axi_wready <= 1'b0;
    end

    // ---- register writes + one-cycle strobe generation ----
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            Relu_En_r       <= 1'b0;
            Img_Waddr_r     <= {Img_Addrw{1'b0}};
            Img_Wdata_r     <= {Pixel_W{1'b0}};
            Kernel_Windex_r <= {Kidxw{1'b0}};
            Kernel_Wdata_r  <= {Kernel_W{1'b0}};
            Start_pulse     <= 1'b0;
            Img_We_pulse    <= 1'b0;
            Kernel_We_pulse <= 1'b0;
        end else begin
            // pulses default low every cycle unless re-asserted below
            Start_pulse     <= 1'b0;
            Img_We_pulse    <= 1'b0;
            Kernel_We_pulse <= 1'b0;

            if (axi_wr_en) begin
                case (axi_awaddr_l[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB])
                    3'h0: begin // CTRL
                        if (s_axi_wstrb[0]) begin
                            Start_pulse <= s_axi_wdata[0];
                            Relu_En_r   <= s_axi_wdata[1];
                        end
                    end
                    3'h2: begin // IMG_WADDR
                        if (s_axi_wstrb[0] || s_axi_wstrb[1])
                            Img_Waddr_r <= s_axi_wdata[Img_Addrw-1:0];
                    end
                    3'h3: begin // IMG_WDATA -> pulses Img_We
                        if (s_axi_wstrb[0]) begin
                            Img_Wdata_r  <= s_axi_wdata[Pixel_W-1:0];
                            Img_We_pulse <= 1'b1;
                        end
                    end
                    3'h4: begin // KERNEL_WINDEX
                        if (s_axi_wstrb[0])
                            Kernel_Windex_r <= s_axi_wdata[Kidxw-1:0];
                    end
                    3'h5: begin // KERNEL_WDATA -> pulses Kernel_We
                        if (s_axi_wstrb[0]) begin
                            Kernel_Wdata_r  <= s_axi_wdata[Kernel_W-1:0];
                            Kernel_We_pulse <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else if (axi_wr_en && ~s_axi_bvalid) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= 2'b00; // OKAY
        end else if (s_axi_bready && s_axi_bvalid) begin
            s_axi_bvalid <= 1'b0;
        end
    end

    // ---- AXI read address/data channel ----
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr_l;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            axi_araddr_l  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else if (~s_axi_arready && s_axi_arvalid) begin
            s_axi_arready <= 1'b1;
            axi_araddr_l  <= s_axi_araddr;
        end else begin
            s_axi_arready <= 1'b0;
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid    <= 1'b0;
            s_axi_rresp     <= 2'b00;
            Out_Rd_En_pulse <= 1'b0;
        end else begin
            Out_Rd_En_pulse <= 1'b0;
            if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
                if (axi_araddr_l[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] == 3'h6) // OUT_DATA
                    Out_Rd_En_pulse <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    always @(*) begin
        case (axi_araddr_l[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB])
            3'h0:    s_axi_rdata = {{(C_S_AXI_DATA_WIDTH-2){1'b0}}, Relu_En_r, 1'b0};
            3'h1:    s_axi_rdata = {{(C_S_AXI_DATA_WIDTH-4){1'b0}}, Out_Valid_w, Out_Full_w, Scan_Done_w, Busy_w};
            3'h2:    s_axi_rdata = {{(C_S_AXI_DATA_WIDTH-Img_Addrw){1'b0}}, Img_Waddr_r};
            3'h4:    s_axi_rdata = {{(C_S_AXI_DATA_WIDTH-Kidxw){1'b0}}, Kernel_Windex_r};
            3'h6:    s_axi_rdata = {{(C_S_AXI_DATA_WIDTH-Acc_W){Out_Data_w[Acc_W-1]}}, Out_Data_w}; // sign-extended
            default: s_axi_rdata = {C_S_AXI_DATA_WIDTH{1'b0}};
        endcase
    end

    // ---- instantiate the accelerator (unchanged from the board-agnostic core) ----
    top #(
        .Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W),
        .Img_W(Img_W), .Img_H(Img_H), .K(K),
        .Img_Addrw(Img_Addrw), .Kidxw(Kidxw)
    ) U_Top (
        .Clk           (s_axi_aclk),
        .Rst_N         (s_axi_aresetn),
        .Start         (Start_pulse),
        .Relu_En       (Relu_En_r),
        .Busy          (Busy_w),
        .Scan_Done     (Scan_Done_w),
        .Img_We        (Img_We_pulse),
        .Img_Waddr     (Img_Waddr_r),
        .Img_Wdata     (Img_Wdata_r),
        .Kernel_We     (Kernel_We_pulse),
        .Kernel_Windex (Kernel_Windex_r),
        .Kernel_Wdata  (Kernel_Wdata_r),
        .Out_Rd_En     (Out_Rd_En_pulse),
        .Out_Data      (Out_Data_w),
        .Out_Valid     (Out_Valid_w),
        .Out_Full      (Out_Full_w)
    );

endmodule

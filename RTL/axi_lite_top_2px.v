//==============================================================================
// axi_lite_top_2px.v | NEW MODULE (2026-09-12)
//
// Did not exist before this fix: the Verification_Test_Plan.xlsx had four
// rows (TIM-08, TIM-09, ERR-06, ERR-07) written against an "AXI-Lite
// Wrapper" that had no RTL file anywhere in this repo - those rows were
// literally untestable. This is a standard AXI4-Lite slave (the
// aw_en-arbitrated write-channel pattern Vivado's own peripheral template
// uses - TIM-08 in the test plan explicitly names that arbitration signal)
// wrapping top_2px.v.
//
// Register map (all registers 32-bit, word-aligned, byte offsets):
//   0x00 CONTROL/STATUS
//        write: bit0 = Start (self-clearing pulse), bit1 = Relu_En (level, RW)
//        read : bit0 = Busy, bit1 = Scan_Done (live), bit2 = Out_Full,
//               bit3 = Out_Valid, bit4 = Relu_En (readback)
//   0x08 IMG_WADDR   - write: latches the image write address for the next
//                       0x0C write (RW, readback of the latch)
//   0x0C IMG_WDATA   - write: pulses Img_We=1 for exactly 1 cycle, using the
//                       address latched at 0x08 and this write's low
//                       Pixel_W bits as Img_Wdata
//   0x10 KERNEL_WINDEX - write: latches the kernel coefficient index for the
//                         next 0x14 write (RW, readback of the latch)
//   0x14 KERNEL_WDATA  - write: pulses Kernel_We=1 for exactly 1 cycle, using
//                         the index latched at 0x10 and this write's low
//                         Kernel_W bits as Kernel_Wdata (matches TIM-08:
//                         "Kernel_We pulses for exactly 1 cycle at the
//                         address latched in axi_awaddr_l")
//   0x18 OUT_DATA    - read: pulses Out_Rd_En=1 for exactly 1 cycle,
//                       unconditionally, every time this address is read
//                       (matches ERR-07: "Out_Rd_En pulses unconditionally
//                       on any 0x18 read, no Out_Valid guard on the AXI
//                       side"); RDATA returns Out_Data0 sign-extended to 32
//                       bits, sampled the cycle of the read (matches TIM-09)
//
// Any other decoded offset (e.g. 0x1C): the `default: ;` case below takes no
// internal action; BRESP/RRESP still return OKAY - there is no SLVERR/DECERR
// path, which matches ERR-06's expected result exactly (documented as a
// reported limitation, not fixed here since the test plan describes it as
// the expected/passing behavior for that row).
//==============================================================================
`timescale 1ns/1ps
module axi_lite_top_2px #(
    parameter Pixel_W   = 8,
    parameter Kernel_W  = 8,
    parameter Acc_W     = 20,
    parameter Img_W     = 32,
    parameter Img_H     = 32,
    parameter K         = 3,
    parameter Img_Addrw = 10,
    parameter Kidxw     = 4,
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 5     // 0x00..0x1C, word-aligned
)(
    input  wire                                Clk,
    input  wire                                Rst_N,

    // AXI4-Lite write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  wire                                s_axi_awvalid,
    output wire                                s_axi_awready,
    // AXI4-Lite write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   s_axi_wstrb,
    input  wire                                s_axi_wvalid,
    output wire                                s_axi_wready,
    // AXI4-Lite write response channel
    output wire [1:0]                          s_axi_bresp,
    output wire                                s_axi_bvalid,
    input  wire                                s_axi_bready,
    // AXI4-Lite read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  wire                                s_axi_arvalid,
    output wire                                s_axi_arready,
    // AXI4-Lite read data channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output wire [1:0]                          s_axi_rresp,
    output wire                                s_axi_rvalid,
    input  wire                                s_axi_rready
);
    localparam ADDR_LSB = 2;
    localparam [1:0] AXI_OKAY = 2'b00;

    // ---------------- write-address-channel handshake (aw_en arbitrated) ----------------
    reg axi_awready;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_l;
    reg axi_wready;
    reg axi_bvalid;
    reg aw_en;

    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = AXI_OKAY;
    assign s_axi_bvalid  = axi_bvalid;

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            axi_awready  <= 1'b0;
            axi_awaddr_l <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            aw_en        <= 1'b1;
        end else begin
            if (~axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                axi_awready  <= 1'b1;
                axi_awaddr_l <= s_axi_awaddr;
                aw_en        <= 1'b0;
            end else if (s_axi_bvalid && s_axi_bready) begin
                aw_en        <= 1'b1;
                axi_awready  <= 1'b0;
            end else begin
                axi_awready  <= 1'b0;
            end
        end
    end

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) axi_wready <= 1'b0;
        else if (~axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en) axi_wready <= 1'b1;
        else axi_wready <= 1'b0;
    end

    wire Reg_Write_En = axi_wready && s_axi_wvalid && axi_awready && s_axi_awvalid;

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) axi_bvalid <= 1'b0;
        else if (axi_awready && s_axi_awvalid && ~axi_bvalid && axi_wready && s_axi_wvalid) axi_bvalid <= 1'b1;
        else if (s_axi_bready && axi_bvalid) axi_bvalid <= 1'b0;
    end

    // ---------------- register file / register-mapped side effects ----------------
    reg                          Reg_Relu_En;
    reg  [Img_Addrw-1:0]         Reg_Img_Waddr;
    reg  [Kidxw-1:0]             Reg_Kernel_Windex;
    reg                          Start_Pulse;
    reg                          Img_We_Pulse;
    reg  [Pixel_W-1:0]           Img_Wdata_Latch;
    reg                          Kernel_We_Pulse;
    reg  signed [Kernel_W-1:0]   Kernel_Wdata_Latch;

    wire Busy_w, Scan_Done_w, Out_Full_w, Out_Valid_w;
    wire signed [Acc_W-1:0] Out_Data0_w, Out_Data1_w;

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Reg_Relu_En        <= 1'b0;
            Reg_Img_Waddr      <= {Img_Addrw{1'b0}};
            Reg_Kernel_Windex  <= {Kidxw{1'b0}};
            Start_Pulse        <= 1'b0;
            Img_We_Pulse       <= 1'b0;
            Img_Wdata_Latch    <= {Pixel_W{1'b0}};
            Kernel_We_Pulse    <= 1'b0;
            Kernel_Wdata_Latch <= {Kernel_W{1'b0}};
        end else begin
            // self-clearing pulses: default low every cycle unless (re)asserted below
            Start_Pulse     <= 1'b0;
            Img_We_Pulse    <= 1'b0;
            Kernel_We_Pulse <= 1'b0;

            if (Reg_Write_En) begin
                case (axi_awaddr_l[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB])
                    3'h0: begin // CONTROL (0x00)
                        if (s_axi_wstrb[0]) begin
                            Start_Pulse <= s_axi_wdata[0];
                            Reg_Relu_En <= s_axi_wdata[1];
                        end
                    end
                    3'h2: begin // IMG_WADDR (0x08)
                        if (s_axi_wstrb[0]) Reg_Img_Waddr <= s_axi_wdata[Img_Addrw-1:0];
                    end
                    3'h3: begin // IMG_WDATA (0x0C) - pulses Img_We
                        if (s_axi_wstrb[0]) begin
                            Img_Wdata_Latch <= s_axi_wdata[Pixel_W-1:0];
                            Img_We_Pulse    <= 1'b1;
                        end
                    end
                    3'h4: begin // KERNEL_WINDEX (0x10)
                        if (s_axi_wstrb[0]) Reg_Kernel_Windex <= s_axi_wdata[Kidxw-1:0];
                    end
                    3'h5: begin // KERNEL_WDATA (0x14) - pulses Kernel_We
                        if (s_axi_wstrb[0]) begin
                            Kernel_Wdata_Latch <= s_axi_wdata[Kernel_W-1:0];
                            Kernel_We_Pulse    <= 1'b1;
                        end
                    end
                    default: ; // 0x1C and anything else: no internal action (ERR-06)
                endcase
            end
        end
    end

    top_2px #(
        .Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W),
        .Img_W(Img_W), .Img_H(Img_H), .K(K),
        .Img_Addrw(Img_Addrw), .Kidxw(Kidxw)
    ) U_Top (
        .Clk(Clk), .Rst_N(Rst_N),
        .Start(Start_Pulse), .Relu_En(Reg_Relu_En),
        .Busy(Busy_w), .Scan_Done(Scan_Done_w),
        .Img_We(Img_We_Pulse), .Img_Waddr(Reg_Img_Waddr), .Img_Wdata(Img_Wdata_Latch),
        .Kernel_We(Kernel_We_Pulse), .Kernel_Windex(Reg_Kernel_Windex), .Kernel_Wdata(Kernel_Wdata_Latch),
        .Out_Rd_En(Out_Rd_En_Pulse),
        .Out_Data0(Out_Data0_w), .Out_Data1(Out_Data1_w),
        .Out_Valid(Out_Valid_w), .Out_Full(Out_Full_w)
    );

    // ---------------- read-address-channel handshake ----------------
    reg axi_arready;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr_l;
    reg axi_rvalid;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg Out_Rd_En_Pulse;

    assign s_axi_arready = axi_arready;
    assign s_axi_rvalid  = axi_rvalid;
    assign s_axi_rresp   = AXI_OKAY;
    assign s_axi_rdata   = axi_rdata;

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            axi_arready  <= 1'b0;
            axi_araddr_l <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else if (~axi_arready && s_axi_arvalid) begin
            axi_arready  <= 1'b1;
            axi_araddr_l <= s_axi_araddr;
        end else begin
            axi_arready  <= 1'b0;
        end
    end

    wire Reg_Read_En = axi_arready && s_axi_arvalid && ~axi_rvalid;

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            axi_rvalid      <= 1'b0;
            axi_rdata       <= {C_S_AXI_DATA_WIDTH{1'b0}};
            Out_Rd_En_Pulse <= 1'b0;
        end else begin
            Out_Rd_En_Pulse <= 1'b0; // self-clearing pulse
            if (Reg_Read_En) begin
                axi_rvalid <= 1'b1;
                case (axi_araddr_l[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB])
                    3'h0: axi_rdata <= {{(C_S_AXI_DATA_WIDTH-5){1'b0}}, Reg_Relu_En, Out_Valid_w, Out_Full_w, Scan_Done_w, Busy_w};
                    3'h2: axi_rdata <= {{(C_S_AXI_DATA_WIDTH-Img_Addrw){1'b0}}, Reg_Img_Waddr};
                    3'h4: axi_rdata <= {{(C_S_AXI_DATA_WIDTH-Kidxw){1'b0}}, Reg_Kernel_Windex};
                    3'h6: begin // OUT_DATA (0x18): pulse Out_Rd_En unconditionally, return Out_Data0 sign-extended (TIM-09 / ERR-07)
                        axi_rdata       <= {{(C_S_AXI_DATA_WIDTH-Acc_W){Out_Data0_w[Acc_W-1]}}, Out_Data0_w};
                        Out_Rd_En_Pulse <= 1'b1;
                    end
                    default: axi_rdata <= {C_S_AXI_DATA_WIDTH{1'b0}};
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end
endmodule

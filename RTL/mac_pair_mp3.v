//==============================================================================
// mac_pair_mp3.v | 3-DSP, 6-cycle exact 2-output/cycle MAC
//==============================================================================
//
// Purpose:
//   Replace the MP4 fabric accumulator with DSP48E1 internal P-register
//   accumulation. 18 exact products are evaluated with only 3 DSPs:
//
//     slot 0 -> L0 L1 L2
//     slot 1 -> L3 L4 L5
//     slot 2 -> L6 L7 L8
//     slot 3 -> R0 R1 R2
//     slot 4 -> R3 R4 R5
//     slot 5 -> R6 R7 R8
//
// Each DSP performs one product per fast cycle and accumulates in its own
// DSP48E1 P register. Left partial sums are captured at the left/right
// boundary. Right partial sums are emitted through an asynchronous result
// FIFO one fast cycle after slot 5 while the next request can begin at slot 0.
// This preserves a 6-fast-cycle initiation interval: 6 * 8.333 ns = 50 ns.
//
// The result FIFO is distributed RAM, so the CDC buffer does not add BRAM.
//==============================================================================
module mac_pair_mp3 #(
    parameter Pixel_W=8, parameter Kernel_W=8, parameter Acc_W=20, parameter K=3
)(
    input wire Clk_Sys, input wire Clk_Fast, input wire Rst_N,
    input wire Fast_Locked, input wire Valid_In,
    input wire [K*K*Pixel_W-1:0] Left_Window_Flat,
    input wire [K*K*Pixel_W-1:0] Right_Window_Flat,
    input wire signed [K*K*Kernel_W-1:0] Kernel_Flat,
    input wire Out_Rd_En,
    output reg Valid_Out,
    output reg signed [Acc_W-1:0] Left_Acc_Out,
    output reg signed [Acc_W-1:0] Right_Acc_Out
);
    localparam integer REQ_W = 2*K*K*Pixel_W + K*K*Kernel_W;
    localparam integer RES_W = 6*Acc_W;

    // -------------------------------------------------------------------------
    // System -> fast request FIFO.  Distributed RAM avoids the BRAM penalty.
    // -------------------------------------------------------------------------
    wire [REQ_W-1:0] Req_Fifo_Din = {Kernel_Flat, Right_Window_Flat, Left_Window_Flat};
    wire [REQ_W-1:0] Req_Fifo_Dout;
    wire Req_Fifo_Full, Req_Fifo_Empty;
    wire Req_Fifo_Overflow, Req_Fifo_Underflow;
    wire Req_Fifo_Wr_Busy, Req_Fifo_Rd_Busy;
    wire Req_Fifo_Wr_En = Valid_In && !Req_Fifo_Full;

    reg Running;
    reg Result_Pending;
    reg [2:0] Slot;
    wire Req_Fifo_Rd_En = Fast_Locked && !Req_Fifo_Empty &&
                           !Result_Pending &&
                           (!Running || (Slot == 3'd5));

    xpm_fifo_async #(
        .CDC_SYNC_STAGES(2),
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(0),
        .FIFO_WRITE_DEPTH(16),
        .FULL_RESET_VALUE(0),
        .PROG_EMPTY_THRESH(5),
        .PROG_FULL_THRESH(12),
        .RD_DATA_COUNT_WIDTH(5),
        .READ_DATA_WIDTH(REQ_W),
        .READ_MODE("fwft"),
        .RELATED_CLOCKS(0),
        .SIM_ASSERT_CHK(1),
        .USE_ADV_FEATURES("0000"),
        .WAKEUP_TIME(0),
        .WRITE_DATA_WIDTH(REQ_W),
        .WR_DATA_COUNT_WIDTH(5)
    ) U_Request_Fifo (
        .rst(~Rst_N), .wr_clk(Clk_Sys), .wr_en(Req_Fifo_Wr_En), .din(Req_Fifo_Din),
        .full(Req_Fifo_Full), .overflow(Req_Fifo_Overflow), .wr_rst_busy(Req_Fifo_Wr_Busy),
        .rd_clk(Clk_Fast), .rd_en(Req_Fifo_Rd_En), .dout(Req_Fifo_Dout),
        .empty(Req_Fifo_Empty), .underflow(Req_Fifo_Underflow), .rd_rst_busy(Req_Fifo_Rd_Busy),
        .prog_full(), .wr_data_count(), .prog_empty(), .rd_data_count(),
        .almost_full(), .almost_empty(), .wr_ack(), .data_valid(),
        .injectsbiterr(1'b0), .injectdbiterr(1'b0), .sbiterr(), .dbiterr()
    );

    reg [K*K*Pixel_W-1:0] Left_Hold_Fast;
    reg [K*K*Pixel_W-1:0] Right_Hold_Fast;
    reg signed [K*K*Kernel_W-1:0] Kernel_Hold_Fast;

    // -------------------------------------------------------------------------
    // Product selection. Each DSP receives one product per fast cycle.
    // -------------------------------------------------------------------------
    reg [Pixel_W-1:0] Pix0, Pix1, Pix2;
    reg signed [Kernel_W-1:0] Coef0, Coef1, Coef2;

    always @* begin
        Pix0 = 0; Pix1 = 0; Pix2 = 0;
        Coef0 = 0; Coef1 = 0; Coef2 = 0;
        case (Slot)
            3'd0: begin
                Pix0=Left_Hold_Fast[1*Pixel_W-1 -: Pixel_W]; Coef0=$signed(Kernel_Hold_Fast[1*Kernel_W-1 -: Kernel_W]);
                Pix1=Left_Hold_Fast[2*Pixel_W-1 -: Pixel_W]; Coef1=$signed(Kernel_Hold_Fast[2*Kernel_W-1 -: Kernel_W]);
                Pix2=Left_Hold_Fast[3*Pixel_W-1 -: Pixel_W]; Coef2=$signed(Kernel_Hold_Fast[3*Kernel_W-1 -: Kernel_W]);
            end
            3'd1: begin
                Pix0=Left_Hold_Fast[4*Pixel_W-1 -: Pixel_W]; Coef0=$signed(Kernel_Hold_Fast[4*Kernel_W-1 -: Kernel_W]);
                Pix1=Left_Hold_Fast[5*Pixel_W-1 -: Pixel_W]; Coef1=$signed(Kernel_Hold_Fast[5*Kernel_W-1 -: Kernel_W]);
                Pix2=Left_Hold_Fast[6*Pixel_W-1 -: Pixel_W]; Coef2=$signed(Kernel_Hold_Fast[6*Kernel_W-1 -: Kernel_W]);
            end
            3'd2: begin
                Pix0=Left_Hold_Fast[7*Pixel_W-1 -: Pixel_W]; Coef0=$signed(Kernel_Hold_Fast[7*Kernel_W-1 -: Kernel_W]);
                Pix1=Left_Hold_Fast[8*Pixel_W-1 -: Pixel_W]; Coef1=$signed(Kernel_Hold_Fast[8*Kernel_W-1 -: Kernel_W]);
                Pix2=Left_Hold_Fast[9*Pixel_W-1 -: Pixel_W]; Coef2=$signed(Kernel_Hold_Fast[9*Kernel_W-1 -: Kernel_W]);
            end
            3'd3: begin
                Pix0=Right_Hold_Fast[1*Pixel_W-1 -: Pixel_W]; Coef0=$signed(Kernel_Hold_Fast[1*Kernel_W-1 -: Kernel_W]);
                Pix1=Right_Hold_Fast[2*Pixel_W-1 -: Pixel_W]; Coef1=$signed(Kernel_Hold_Fast[2*Kernel_W-1 -: Kernel_W]);
                Pix2=Right_Hold_Fast[3*Pixel_W-1 -: Pixel_W]; Coef2=$signed(Kernel_Hold_Fast[3*Kernel_W-1 -: Kernel_W]);
            end
            3'd4: begin
                Pix0=Right_Hold_Fast[4*Pixel_W-1 -: Pixel_W]; Coef0=$signed(Kernel_Hold_Fast[4*Kernel_W-1 -: Kernel_W]);
                Pix1=Right_Hold_Fast[5*Pixel_W-1 -: Pixel_W]; Coef1=$signed(Kernel_Hold_Fast[5*Kernel_W-1 -: Kernel_W]);
                Pix2=Right_Hold_Fast[6*Pixel_W-1 -: Pixel_W]; Coef2=$signed(Kernel_Hold_Fast[6*Kernel_W-1 -: Kernel_W]);
            end
            default: begin
                Pix0=Right_Hold_Fast[7*Pixel_W-1 -: Pixel_W]; Coef0=$signed(Kernel_Hold_Fast[7*Kernel_W-1 -: Kernel_W]);
                Pix1=Right_Hold_Fast[8*Pixel_W-1 -: Pixel_W]; Coef1=$signed(Kernel_Hold_Fast[8*Kernel_W-1 -: Kernel_W]);
                Pix2=Right_Hold_Fast[9*Pixel_W-1 -: Pixel_W]; Coef2=$signed(Kernel_Hold_Fast[9*Kernel_W-1 -: Kernel_W]);
            end
        endcase
    end

    // First slot of each 3-product group starts from zero via C+A*B.
    // Remaining slots use the DSP48E1 internal P+A*B accumulator.
    wire [6:0] Dsp_Opmode = ((Slot == 3'd0) || (Slot == 3'd3)) ? 7'b0110101 : 7'b0100101;
    wire Dsp_CE = Fast_Locked && Running && !Result_Pending;
    wire [29:0] A0 = {{22{1'b0}}, Pix0};
    wire [29:0] A1 = {{22{1'b0}}, Pix1};
    wire [29:0] A2 = {{22{1'b0}}, Pix2};
    wire [17:0] B0 = {{10{Coef0[Kernel_W-1]}}, Coef0};
    wire [17:0] B1 = {{10{Coef1[Kernel_W-1]}}, Coef1};
    wire [17:0] B2 = {{10{Coef2[Kernel_W-1]}}, Coef2};
    wire signed [47:0] Dsp_P0, Dsp_P1, Dsp_P2;

    DSP48E1 #(
        .A_INPUT("DIRECT"), .B_INPUT("DIRECT"), .USE_MULT("MULTIPLY"), .USE_SIMD("ONE48"),
        .AREG(0), .BREG(0), .MREG(0), .PREG(1), .CREG(0), .DREG(0), .ADREG(0),
        .ACASCREG(0), .BCASCREG(0), .INMODEREG(0), .OPMODEREG(0), .ALUMODEREG(0),
        .CARRYINSELREG(0), .CARRYINREG(0), .USE_DPORT("FALSE")
    ) U_DSP0 (
        .A(A0), .B(B0), .C(48'd0), .D(25'd0), .ACIN(30'd0), .BCIN(18'd0), .PCIN(48'd0),
        .INMODE(5'b0), .OPMODE(Dsp_Opmode), .ALUMODE(4'b0), .CARRYINSEL(3'b0), .CARRYIN(1'b0),
        .MULTSIGNIN(1'b0), .CARRYCASCIN(1'b0), .CLK(Clk_Fast),
        .CEA1(1'b0), .CEA2(1'b0), .CEAD(1'b0), .CEALUMODE(1'b0), .CEB1(1'b0), .CEB2(1'b0),
        .CEC(1'b0), .CECARRYIN(1'b0), .CECTRL(1'b0), .CED(1'b0), .CEINMODE(1'b0), .CEM(1'b0), .CEP(Dsp_CE),
        .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0),
        .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(~Rst_N),
        .ACOUT(), .BCOUT(), .CARRYCASCOUT(), .MULTSIGNOUT(), .PCOUT(), .OVERFLOW(), .PATTERNBDETECT(),
        .PATTERNDETECT(), .UNDERFLOW(), .CARRYOUT(), .P(Dsp_P0)
    );

    DSP48E1 #(
        .A_INPUT("DIRECT"), .B_INPUT("DIRECT"), .USE_MULT("MULTIPLY"), .USE_SIMD("ONE48"),
        .AREG(0), .BREG(0), .MREG(0), .PREG(1), .CREG(0), .DREG(0), .ADREG(0),
        .ACASCREG(0), .BCASCREG(0), .INMODEREG(0), .OPMODEREG(0), .ALUMODEREG(0),
        .CARRYINSELREG(0), .CARRYINREG(0), .USE_DPORT("FALSE")
    ) U_DSP1 (
        .A(A1), .B(B1), .C(48'd0), .D(25'd0), .ACIN(30'd0), .BCIN(18'd0), .PCIN(48'd0),
        .INMODE(5'b0), .OPMODE(Dsp_Opmode), .ALUMODE(4'b0), .CARRYINSEL(3'b0), .CARRYIN(1'b0),
        .MULTSIGNIN(1'b0), .CARRYCASCIN(1'b0), .CLK(Clk_Fast),
        .CEA1(1'b0), .CEA2(1'b0), .CEAD(1'b0), .CEALUMODE(1'b0), .CEB1(1'b0), .CEB2(1'b0),
        .CEC(1'b0), .CECARRYIN(1'b0), .CECTRL(1'b0), .CED(1'b0), .CEINMODE(1'b0), .CEM(1'b0), .CEP(Dsp_CE),
        .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0),
        .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(~Rst_N),
        .ACOUT(), .BCOUT(), .CARRYCASCOUT(), .MULTSIGNOUT(), .PCOUT(), .OVERFLOW(), .PATTERNBDETECT(),
        .PATTERNDETECT(), .UNDERFLOW(), .CARRYOUT(), .P(Dsp_P1)
    );

    DSP48E1 #(
        .A_INPUT("DIRECT"), .B_INPUT("DIRECT"), .USE_MULT("MULTIPLY"), .USE_SIMD("ONE48"),
        .AREG(0), .BREG(0), .MREG(0), .PREG(1), .CREG(0), .DREG(0), .ADREG(0),
        .ACASCREG(0), .BCASCREG(0), .INMODEREG(0), .OPMODEREG(0), .ALUMODEREG(0),
        .CARRYINSELREG(0), .CARRYINREG(0), .USE_DPORT("FALSE")
    ) U_DSP2 (
        .A(A2), .B(B2), .C(48'd0), .D(25'd0), .ACIN(30'd0), .BCIN(18'd0), .PCIN(48'd0),
        .INMODE(5'b0), .OPMODE(Dsp_Opmode), .ALUMODE(4'b0), .CARRYINSEL(3'b0), .CARRYIN(1'b0),
        .MULTSIGNIN(1'b0), .CARRYCASCIN(1'b0), .CLK(Clk_Fast),
        .CEA1(1'b0), .CEA2(1'b0), .CEAD(1'b0), .CEALUMODE(1'b0), .CEB1(1'b0), .CEB2(1'b0),
        .CEC(1'b0), .CECARRYIN(1'b0), .CECTRL(1'b0), .CED(1'b0), .CEINMODE(1'b0), .CEM(1'b0), .CEP(Dsp_CE),
        .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0),
        .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(~Rst_N),
        .ACOUT(), .BCOUT(), .CARRYCASCOUT(), .MULTSIGNOUT(), .PCOUT(), .OVERFLOW(), .PATTERNBDETECT(),
        .PATTERNDETECT(), .UNDERFLOW(), .CARRYOUT(), .P(Dsp_P2)
    );

    // Capture left partial sums at the boundary. At the slot-3 edge the
    // registered DSP P outputs contain the complete left 9-product sums.
    reg signed [Acc_W-1:0] Left_Part0, Left_Part1, Left_Part2;

    // -------------------------------------------------------------------------
    // Fast -> system result FIFO. Payload carries three partial sums per
    // output, avoiding a fast-clock fabric adder on the critical path.
    // -------------------------------------------------------------------------
    wire [RES_W-1:0] Result_Fifo_Din = {
        $signed(Dsp_P2[Acc_W-1:0]), $signed(Dsp_P1[Acc_W-1:0]), $signed(Dsp_P0[Acc_W-1:0]),
        Left_Part2, Left_Part1, Left_Part0
    };
    wire [RES_W-1:0] Result_Fifo_Dout;
    wire Result_Fifo_Full, Result_Fifo_Empty;
    wire Result_Fifo_Overflow, Result_Fifo_Underflow;
    wire Result_Fifo_Wr_Busy, Result_Fifo_Rd_Busy;
    wire Result_Fifo_Wr_En = Result_Pending && !Result_Fifo_Full && Fast_Locked;
    wire Result_Fifo_Rd_En = Out_Rd_En && !Result_Fifo_Empty;

    xpm_fifo_async #(
        .CDC_SYNC_STAGES(2), .DOUT_RESET_VALUE("0"), .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"), .FIFO_READ_LATENCY(0), .FIFO_WRITE_DEPTH(4),
        .FULL_RESET_VALUE(0), .READ_DATA_WIDTH(RES_W), .READ_MODE("fwft"),
        .RELATED_CLOCKS(0), .SIM_ASSERT_CHK(1), .USE_ADV_FEATURES("0000"),
        .WAKEUP_TIME(0), .WRITE_DATA_WIDTH(RES_W)
    ) U_Result_Fifo (
        .rst(~Rst_N), .wr_clk(Clk_Fast), .wr_en(Result_Fifo_Wr_En), .din(Result_Fifo_Din),
        .full(Result_Fifo_Full), .overflow(Result_Fifo_Overflow), .wr_rst_busy(Result_Fifo_Wr_Busy),
        .rd_clk(Clk_Sys), .rd_en(Result_Fifo_Rd_En), .dout(Result_Fifo_Dout),
        .empty(Result_Fifo_Empty), .underflow(Result_Fifo_Underflow), .rd_rst_busy(Result_Fifo_Rd_Busy),
        .prog_full(), .wr_data_count(), .prog_empty(), .rd_data_count(), .almost_full(),
        .almost_empty(), .wr_ack(), .data_valid(), .injectsbiterr(1'b0), .injectdbiterr(1'b0),
        .sbiterr(), .dbiterr()
    );

    wire signed [Acc_W-1:0] Result_L0 = $signed(Result_Fifo_Dout[Acc_W-1:0]);
    wire signed [Acc_W-1:0] Result_L1 = $signed(Result_Fifo_Dout[2*Acc_W-1:Acc_W]);
    wire signed [Acc_W-1:0] Result_L2 = $signed(Result_Fifo_Dout[3*Acc_W-1:2*Acc_W]);
    wire signed [Acc_W-1:0] Result_R0 = $signed(Result_Fifo_Dout[4*Acc_W-1:3*Acc_W]);
    wire signed [Acc_W-1:0] Result_R1 = $signed(Result_Fifo_Dout[5*Acc_W-1:4*Acc_W]);
    wire signed [Acc_W-1:0] Result_R2 = $signed(Result_Fifo_Dout[6*Acc_W-1:5*Acc_W]);

    wire signed [Acc_W:0] Result_Left_Sum = $signed(Result_L0) + $signed(Result_L1) + $signed(Result_L2);
    wire signed [Acc_W:0] Result_Right_Sum = $signed(Result_R0) + $signed(Result_R1) + $signed(Result_R2);

    integer I;
    always @(posedge Clk_Fast or negedge Rst_N) begin
        if (!Rst_N) begin
            Running <= 0;
            Result_Pending <= 0;
            Slot <= 0;
            Left_Hold_Fast <= 0;
            Right_Hold_Fast <= 0;
            Kernel_Hold_Fast <= 0;
            Left_Part0 <= 0;
            Left_Part1 <= 0;
            Left_Part2 <= 0;
        end else if (!Fast_Locked) begin
            Running <= 0;
            Result_Pending <= 0;
            Slot <= 0;
        end else begin
            // Emit the completed pair one fast cycle after slot 5.  When a
            // prefetched request exists, the DSPs simultaneously begin its
            // slot-0 product on this same edge, so the initiation interval is
            // still exactly six fast cycles.
            if (Result_Pending && !Result_Fifo_Full) begin
                Result_Pending <= 0;
            end

            if (Req_Fifo_Rd_En) begin
                Left_Hold_Fast <= Req_Fifo_Dout[K*K*Pixel_W-1:0];
                Right_Hold_Fast <= Req_Fifo_Dout[2*K*K*Pixel_W-1:K*K*Pixel_W];
                Kernel_Hold_Fast <= Req_Fifo_Dout[REQ_W-1:2*K*K*Pixel_W];
                Running <= 1;
                Slot <= 0;
            end else if (Running && !Result_Pending) begin
                case (Slot)
                    3'd0: Slot <= 1;
                    3'd1: Slot <= 2;
                    3'd2: Slot <= 3;
                    3'd3: begin
                        Left_Part0 <= Dsp_P0[Acc_W-1:0];
                        Left_Part1 <= Dsp_P1[Acc_W-1:0];
                        Left_Part2 <= Dsp_P2[Acc_W-1:0];
                        Slot <= 4;
                    end
                    3'd4: Slot <= 5;
                    3'd5: begin
                        // Read the next request at the slot-5 edge. The DSP
                        // samples the old window before these nonblocking
                        // assignments take effect; slot 0 next edge therefore
                        // sees the new request without a bubble.
                        Slot <= 0;
                        Result_Pending <= 1;
                        if (Req_Fifo_Empty || Result_Fifo_Full)
                            Running <= 0;
                    end
                    default: begin Slot <= 0; Running <= 0; end
                endcase
            end
        end
    end

    // System-domain result consumer. The three partial sums are added at
    // 20 MHz, safely away from the 120 MHz timing-critical MAC path.
    always @(posedge Clk_Sys or negedge Rst_N) begin
        if (!Rst_N) begin
            Valid_Out <= 0;
            Left_Acc_Out <= 0;
            Right_Acc_Out <= 0;
        end else begin
            Valid_Out <= 0;
            if (Result_Fifo_Rd_En) begin
                Left_Acc_Out <= Result_Left_Sum[Acc_W-1:0];
                Right_Acc_Out <= Result_Right_Sum[Acc_W-1:0];
                Valid_Out <= 1;
            end
        end
    end
endmodule

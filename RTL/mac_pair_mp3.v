//==============================================================================
// mac_pair_mp3.v | 3-DSP, 6-cycle exact 2-output/cycle MAC
//==============================================================================
// 18 exact products are evaluated with three DSP48E1 slices:
//   slot 0 -> L0 L1 L2
//   slot 1 -> L3 L4 L5
//   slot 2 -> L6 L7 L8
//   slot 3 -> R0 R1 R2
//   slot 4 -> R3 R4 R5
//   slot 5 -> R6 R7 R8
//
// DSP48E1 P-register accumulation removes the previous 20-bit fabric carry
// chain. Three partial sums per output cross the CDC boundary; final 3-way
// additions occur at 20 MHz.
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
    localparam integer REQ_W=2*K*K*Pixel_W+K*K*Kernel_W;
    localparam integer RES_W=6*Acc_W;

    wire [REQ_W-1:0] Req_Din={Kernel_Flat,Right_Window_Flat,Left_Window_Flat};
    wire [REQ_W-1:0] Req_Dout;
    wire Req_Full,Req_Empty,Req_Overflow,Req_Underflow,Req_WBusy,Req_RBusy;
    wire Req_Wr_En=Valid_In&&!Req_Full;
    reg Running,Result_Pending;
    reg [2:0] Slot;
    wire Req_Rd_En=Fast_Locked&&!Req_Empty&&!Result_Pending&&(!Running||(Slot==3'd5));

    xpm_fifo_async #(
        .CDC_SYNC_STAGES(2),.DOUT_RESET_VALUE("0"),.ECC_MODE("no_ecc"),.FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(0),.FIFO_WRITE_DEPTH(16),.FULL_RESET_VALUE(0),.PROG_EMPTY_THRESH(5),.PROG_FULL_THRESH(12),
        .RD_DATA_COUNT_WIDTH(5),.READ_DATA_WIDTH(REQ_W),.READ_MODE("fwft"),.RELATED_CLOCKS(0),.SIM_ASSERT_CHK(1),
        .USE_ADV_FEATURES("0000"),.WAKEUP_TIME(0),.WRITE_DATA_WIDTH(REQ_W),.WR_DATA_COUNT_WIDTH(5)
    ) U_Req (
        .rst(~Rst_N),.wr_clk(Clk_Sys),.wr_en(Req_Wr_En),.din(Req_Din),.full(Req_Full),.overflow(Req_Overflow),.wr_rst_busy(Req_WBusy),
        .rd_clk(Clk_Fast),.rd_en(Req_Rd_En),.dout(Req_Dout),.empty(Req_Empty),.underflow(Req_Underflow),.rd_rst_busy(Req_RBusy),
        .prog_full(),.wr_data_count(),.prog_empty(),.rd_data_count(),.almost_full(),.almost_empty(),.wr_ack(),.data_valid(),
        .injectsbiterr(1'b0),.injectdbiterr(1'b0),.sbiterr(),.dbiterr()
    );

    reg [K*K*Pixel_W-1:0] LHold,RHold;
    reg signed [K*K*Kernel_W-1:0] KHold;
    reg [Pixel_W-1:0] Pix0,Pix1,Pix2;
    reg signed [Kernel_W-1:0] Coef0,Coef1,Coef2;

    always @* begin
        Pix0=0;Pix1=0;Pix2=0;Coef0=0;Coef1=0;Coef2=0;
        case(Slot)
            3'd0: begin
                Pix0=LHold[1*Pixel_W-1 -: Pixel_W]; Coef0=$signed(KHold[1*Kernel_W-1 -: Kernel_W]);
                Pix1=LHold[2*Pixel_W-1 -: Pixel_W]; Coef1=$signed(KHold[2*Kernel_W-1 -: Kernel_W]);
                Pix2=LHold[3*Pixel_W-1 -: Pixel_W]; Coef2=$signed(KHold[3*Kernel_W-1 -: Kernel_W]);
            end
            3'd1: begin
                Pix0=LHold[4*Pixel_W-1 -: Pixel_W]; Coef0=$signed(KHold[4*Kernel_W-1 -: Kernel_W]);
                Pix1=LHold[5*Pixel_W-1 -: Pixel_W]; Coef1=$signed(KHold[5*Kernel_W-1 -: Kernel_W]);
                Pix2=LHold[6*Pixel_W-1 -: Pixel_W]; Coef2=$signed(KHold[6*Kernel_W-1 -: Kernel_W]);
            end
            3'd2: begin
                Pix0=LHold[7*Pixel_W-1 -: Pixel_W]; Coef0=$signed(KHold[7*Kernel_W-1 -: Kernel_W]);
                Pix1=LHold[8*Pixel_W-1 -: Pixel_W]; Coef1=$signed(KHold[8*Kernel_W-1 -: Kernel_W]);
                Pix2=LHold[9*Pixel_W-1 -: Pixel_W]; Coef2=$signed(KHold[9*Kernel_W-1 -: Kernel_W]);
            end
            3'd3: begin
                Pix0=RHold[1*Pixel_W-1 -: Pixel_W]; Coef0=$signed(KHold[1*Kernel_W-1 -: Kernel_W]);
                Pix1=RHold[2*Pixel_W-1 -: Pixel_W]; Coef1=$signed(KHold[2*Kernel_W-1 -: Kernel_W]);
                Pix2=RHold[3*Pixel_W-1 -: Pixel_W]; Coef2=$signed(KHold[3*Kernel_W-1 -: Kernel_W]);
            end
            3'd4: begin
                Pix0=RHold[4*Pixel_W-1 -: Pixel_W]; Coef0=$signed(KHold[4*Kernel_W-1 -: Kernel_W]);
                Pix1=RHold[5*Pixel_W-1 -: Pixel_W]; Coef1=$signed(KHold[5*Kernel_W-1 -: Kernel_W]);
                Pix2=RHold[6*Pixel_W-1 -: Pixel_W]; Coef2=$signed(KHold[6*Kernel_W-1 -: Kernel_W]);
            end
            default: begin
                Pix0=RHold[7*Pixel_W-1 -: Pixel_W]; Coef0=$signed(KHold[7*Kernel_W-1 -: Kernel_W]);
                Pix1=RHold[8*Pixel_W-1 -: Pixel_W]; Coef1=$signed(KHold[8*Kernel_W-1 -: Kernel_W]);
                Pix2=RHold[9*Pixel_W-1 -: Pixel_W]; Coef2=$signed(KHold[9*Kernel_W-1 -: Kernel_W]);
            end
        endcase
    end

    // C+A*B starts each 3-product group; P+A*B continues it.
    wire [6:0] Dsp_Opmode=((Slot==3'd0)||(Slot==3'd3))?7'b0110101:7'b0100101;
    wire [29:0] A0={{22{1'b0}},Pix0}, A1={{22{1'b0}},Pix1}, A2={{22{1'b0}},Pix2};
    wire [17:0] B0={{10{Coef0[Kernel_W-1]}},Coef0}, B1={{10{Coef1[Kernel_W-1]}},Coef1}, B2={{10{Coef2[Kernel_W-1]}},Coef2};
    wire signed [47:0] P0,P1,P2;
    wire Dsp_CE=Fast_Locked&&Running&&(!Result_Pending||((Slot==3'd0)&&!Result_Full));

    DSP48E1 #(.A_INPUT("DIRECT"),.B_INPUT("DIRECT"),.USE_DPORT("FALSE"),.USE_MULT("MULTIPLY"),.USE_SIMD("ONE48"),
              .AREG(0),.BREG(0),.MREG(0),.PREG(1),.CREG(0),.DREG(0),.ADREG(0),.ACASCREG(0),.BCASCREG(0),.INMODEREG(0),.OPMODEREG(0),.ALUMODEREG(0),.CARRYINSELREG(0),.CARRYINREG(0)) U_DSP0 (
        .A(A0),.B(B0),.C(48'd0),.D(25'd0),.ACIN(30'd0),.BCIN(18'd0),.PCIN(48'd0),.INMODE(5'd0),.OPMODE(Dsp_Opmode),.ALUMODE(4'd0),.CARRYINSEL(3'd0),.CARRYIN(1'b0),.MULTSIGNIN(1'b0),.CARRYCASCIN(1'b0),.CLK(Clk_Fast),
        .CEA1(1'b0),.CEA2(1'b0),.CEAD(1'b0),.CEALUMODE(1'b0),.CEB1(1'b0),.CEB2(1'b0),.CEC(1'b0),.CECARRYIN(1'b0),.CECTRL(1'b0),.CED(1'b0),.CEINMODE(1'b0),.CEM(1'b0),.CEP(Dsp_CE),
        .RSTA(1'b0),.RSTALLCARRYIN(1'b0),.RSTALUMODE(1'b0),.RSTB(1'b0),.RSTC(1'b0),.RSTCTRL(1'b0),.RSTD(1'b0),.RSTINMODE(1'b0),.RSTM(1'b0),.RSTP(~Rst_N),
        .ACOUT(),.BCOUT(),.CARRYCASCOUT(),.MULTSIGNOUT(),.PCOUT(),.OVERFLOW(),.PATTERNBDETECT(),.PATTERNDETECT(),.UNDERFLOW(),.CARRYOUT(),.P(P0));
    DSP48E1 #(.A_INPUT("DIRECT"),.B_INPUT("DIRECT"),.USE_DPORT("FALSE"),.USE_MULT("MULTIPLY"),.USE_SIMD("ONE48"),
              .AREG(0),.BREG(0),.MREG(0),.PREG(1),.CREG(0),.DREG(0),.ADREG(0),.ACASCREG(0),.BCASCREG(0),.INMODEREG(0),.OPMODEREG(0),.ALUMODEREG(0),.CARRYINSELREG(0),.CARRYINREG(0)) U_DSP1 (
        .A(A1),.B(B1),.C(48'd0),.D(25'd0),.ACIN(30'd0),.BCIN(18'd0),.PCIN(48'd0),.INMODE(5'd0),.OPMODE(Dsp_Opmode),.ALUMODE(4'd0),.CARRYINSEL(3'd0),.CARRYIN(1'b0),.MULTSIGNIN(1'b0),.CARRYCASCIN(1'b0),.CLK(Clk_Fast),
        .CEA1(1'b0),.CEA2(1'b0),.CEAD(1'b0),.CEALUMODE(1'b0),.CEB1(1'b0),.CEB2(1'b0),.CEC(1'b0),.CECARRYIN(1'b0),.CECTRL(1'b0),.CED(1'b0),.CEINMODE(1'b0),.CEM(1'b0),.CEP(Dsp_CE),
        .RSTA(1'b0),.RSTALLCARRYIN(1'b0),.RSTALUMODE(1'b0),.RSTB(1'b0),.RSTC(1'b0),.RSTCTRL(1'b0),.RSTD(1'b0),.RSTINMODE(1'b0),.RSTM(1'b0),.RSTP(~Rst_N),
        .ACOUT(),.BCOUT(),.CARRYCASCOUT(),.MULTSIGNOUT(),.PCOUT(),.OVERFLOW(),.PATTERNBDETECT(),.PATTERNDETECT(),.UNDERFLOW(),.CARRYOUT(),.P(P1));
    DSP48E1 #(.A_INPUT("DIRECT"),.B_INPUT("DIRECT"),.USE_DPORT("FALSE"),.USE_MULT("MULTIPLY"),.USE_SIMD("ONE48"),
              .AREG(0),.BREG(0),.MREG(0),.PREG(1),.CREG(0),.DREG(0),.ADREG(0),.ACASCREG(0),.BCASCREG(0),.INMODEREG(0),.OPMODEREG(0),.ALUMODEREG(0),.CARRYINSELREG(0),.CARRYINREG(0)) U_DSP2 (
        .A(A2),.B(B2),.C(48'd0),.D(25'd0),.ACIN(30'd0),.BCIN(18'd0),.PCIN(48'd0),.INMODE(5'd0),.OPMODE(Dsp_Opmode),.ALUMODE(4'd0),.CARRYINSEL(3'd0),.CARRYIN(1'b0),.MULTSIGNIN(1'b0),.CARRYCASCIN(1'b0),.CLK(Clk_Fast),
        .CEA1(1'b0),.CEA2(1'b0),.CEAD(1'b0),.CEALUMODE(1'b0),.CEB1(1'b0),.CEB2(1'b0),.CEC(1'b0),.CECARRYIN(1'b0),.CECTRL(1'b0),.CED(1'b0),.CEINMODE(1'b0),.CEM(1'b0),.CEP(Dsp_CE),
        .RSTA(1'b0),.RSTALLCARRYIN(1'b0),.RSTALUMODE(1'b0),.RSTB(1'b0),.RSTC(1'b0),.RSTCTRL(1'b0),.RSTD(1'b0),.RSTINMODE(1'b0),.RSTM(1'b0),.RSTP(~Rst_N),
        .ACOUT(),.BCOUT(),.CARRYCASCOUT(),.MULTSIGNOUT(),.PCOUT(),.OVERFLOW(),.PATTERNBDETECT(),.PATTERNDETECT(),.UNDERFLOW(),.CARRYOUT(),.P(P2));

    reg signed [Acc_W-1:0] Left_Part0,Left_Part1,Left_Part2;
    wire [RES_W-1:0] Result_Din={P2[Acc_W-1:0],P1[Acc_W-1:0],P0[Acc_W-1:0],Left_Part2,Left_Part1,Left_Part0};
    wire [RES_W-1:0] Result_Dout;
    wire Result_Full,Result_Empty,Result_Overflow,Result_Underflow,Result_WBusy,Result_RBusy;
    wire Result_Wr_En=Result_Pending&&!Result_Full&&Fast_Locked;
    wire Result_Rd_En=Out_Rd_En&&!Result_Empty;

    xpm_fifo_async #(.CDC_SYNC_STAGES(2),.DOUT_RESET_VALUE("0"),.ECC_MODE("no_ecc"),.FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(0),.FIFO_WRITE_DEPTH(4),.FULL_RESET_VALUE(0),.READ_DATA_WIDTH(RES_W),.READ_MODE("fwft"),
        .RELATED_CLOCKS(0),.SIM_ASSERT_CHK(1),.USE_ADV_FEATURES("0000"),.WAKEUP_TIME(0),.WRITE_DATA_WIDTH(RES_W)) U_Result (
        .rst(~Rst_N),.wr_clk(Clk_Fast),.wr_en(Result_Wr_En),.din(Result_Din),.full(Result_Full),.overflow(Result_Overflow),.wr_rst_busy(Result_WBusy),
        .rd_clk(Clk_Sys),.rd_en(Result_Rd_En),.dout(Result_Dout),.empty(Result_Empty),.underflow(Result_Underflow),.rd_rst_busy(Result_RBusy),
        .prog_full(),.wr_data_count(),.prog_empty(),.rd_data_count(),.almost_full(),.almost_empty(),.wr_ack(),.data_valid(),.injectsbiterr(1'b0),.injectdbiterr(1'b0),.sbiterr(),.dbiterr());

    wire signed [Acc_W-1:0] L0=$signed(Result_Dout[Acc_W-1:0]);
    wire signed [Acc_W-1:0] L1=$signed(Result_Dout[2*Acc_W-1:Acc_W]);
    wire signed [Acc_W-1:0] L2=$signed(Result_Dout[3*Acc_W-1:2*Acc_W]);
    wire signed [Acc_W-1:0] R0=$signed(Result_Dout[4*Acc_W-1:3*Acc_W]);
    wire signed [Acc_W-1:0] R1=$signed(Result_Dout[5*Acc_W-1:4*Acc_W]);
    wire signed [Acc_W-1:0] R2=$signed(Result_Dout[6*Acc_W-1:5*Acc_W]);
    wire signed [Acc_W:0] LSum=$signed(L0)+$signed(L1)+$signed(L2);
    wire signed [Acc_W:0] RSum=$signed(R0)+$signed(R1)+$signed(R2);

    always @(posedge Clk_Fast or negedge Rst_N) begin
        if(!Rst_N) begin Running<=0;Result_Pending<=0;Slot<=0;LHold<=0;RHold<=0;KHold<=0;Left_Part0<=0;Left_Part1<=0;Left_Part2<=0; end
        else if(!Fast_Locked) begin Running<=0;Result_Pending<=0;Slot<=0; end
        else begin
            // First retire the previous result. If a prefetched request is
            // active, slot 0 of that request is executed on this same edge.
            if(Result_Pending&&!Result_Full) begin
                Result_Pending<=0;
                if(Running) Slot<=1; else Slot<=0;
            end
            if(Req_Rd_En) begin
                LHold<=Req_Dout[K*K*Pixel_W-1:0];
                RHold<=Req_Dout[2*K*K*Pixel_W-1:K*K*Pixel_W];
                KHold<=Req_Dout[REQ_W-1:2*K*K*Pixel_W];
                Running<=1; Slot<=0;
            end else if(Running&&!Result_Pending) begin
                case(Slot)
                    3'd0: Slot<=1;
                    3'd1: Slot<=2;
                    3'd2: Slot<=3;
                    3'd3: begin Left_Part0<=P0[Acc_W-1:0]; Left_Part1<=P1[Acc_W-1:0]; Left_Part2<=P2[Acc_W-1:0]; Slot<=4; end
                    3'd4: Slot<=5;
                    3'd5: begin Slot<=0; Result_Pending<=1; if(Req_Empty||Result_Full) Running<=0; end
                    default: begin Slot<=0;Running<=0; end
                endcase
            end
        end
    end

    always @(posedge Clk_Sys or negedge Rst_N) begin
        if(!Rst_N) begin Valid_Out<=0;Left_Acc_Out<=0;Right_Acc_Out<=0; end
        else begin
            Valid_Out<=0;
            if(Result_Rd_En) begin
                Left_Acc_Out<=LSum[Acc_W-1:0];
                Right_Acc_Out<=RSum[Acc_W-1:0];
                Valid_Out<=1;
            end
        end
    end
endmodule

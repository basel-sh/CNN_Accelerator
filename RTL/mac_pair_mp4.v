//==============================================================================
// mac_pair_mp4.v | Resource-optimized exact 2-output/cycle MAC
//==============================================================================
module mac_pair_mp4 #(
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
    localparam integer Prod_W=16;

    // -------------------------------------------------------------------------
    // System -> fast request FIFO.
    //
    // The previous toggle mailbox could lose requests because the 20 MHz
    // producer can issue one pair every 50 ns while the request synchronizer
    // and 5-cycle MAC transaction introduce more than one fast-clock edge of
    // latency. A toggle is not a queue: two requests can cancel/merge before
    // the fast side observes them.
    //
    // This 16-entry FWFT asynchronous FIFO preserves every input pair. It is
    // forced to distributed RAM so the CDC queue does not consume a BRAM.
    // Payload = left window + right window + 9 signed kernel coefficients.
    // -------------------------------------------------------------------------
    localparam integer REQ_W = 2*K*K*Pixel_W + K*K*Kernel_W;

    wire [REQ_W-1:0] Req_Fifo_Din = {
        Kernel_Flat,
        Right_Window_Flat,
        Left_Window_Flat
    };
    wire [REQ_W-1:0] Req_Fifo_Dout;
    wire Req_Fifo_Full;
    wire Req_Fifo_Empty;
    wire Req_Fifo_Overflow;
    wire Req_Fifo_Underflow;
    wire Req_Fifo_Wr_Busy;
    wire Req_Fifo_Rd_Busy;

    wire Req_Fifo_Wr_En = Valid_In && !Req_Fifo_Full;

    reg Running;
    reg Finish_Pending;
    wire Req_Fifo_Rd_En = Fast_Locked && !Req_Fifo_Empty &&
                           !Running && !Finish_Pending;

    xpm_fifo_async #(
        .CASCADE_HEIGHT(0),
        .CDC_SYNC_STAGES(2),
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .EN_SIM_ASSERT_ERR("warning"),
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
        .sleep(1'b0),
        .rst(~Rst_N),
        .wr_clk(Clk_Sys),
        .wr_en(Req_Fifo_Wr_En),
        .din(Req_Fifo_Din),
        .full(Req_Fifo_Full),
        .overflow(Req_Fifo_Overflow),
        .wr_rst_busy(Req_Fifo_Wr_Busy),
        .rd_clk(Clk_Fast),
        .rd_en(Req_Fifo_Rd_En),
        .dout(Req_Fifo_Dout),
        .empty(Req_Fifo_Empty),
        .underflow(Req_Fifo_Underflow),
        .rd_rst_busy(Req_Fifo_Rd_Busy),
        .prog_full(),
        .wr_data_count(),
        .prog_empty(),
        .rd_data_count(),
        .almost_full(),
        .almost_empty(),
        .wr_ack(),
        .data_valid(),
        .injectsbiterr(1'b0),
        .injectdbiterr(1'b0),
        .sbiterr(),
        .dbiterr()
    );

    reg [K*K*Pixel_W-1:0] Left_Hold_Fast;
    reg [K*K*Pixel_W-1:0] Right_Hold_Fast;
    reg signed [K*K*Kernel_W-1:0] Kernel_Hold_Fast;
    reg [2:0] Slot;
    reg signed [Acc_W-1:0] Acc_A, Acc_B;

    wire [4:0] Idx0=(Slot*4)+0;
    wire [4:0] Idx1=(Slot*4)+1;
    wire [4:0] Idx2=(Slot*4)+2;
    wire [4:0] Idx3=(Slot*4)+3;

    wire [Pixel_W-1:0] Pix0=(Idx0<9)?Left_Hold_Fast[(Idx0+1)*Pixel_W-1 -: Pixel_W]:((Idx0<18)?Right_Hold_Fast[(Idx0-8)*Pixel_W-1 -: Pixel_W]:0);
    wire [Pixel_W-1:0] Pix1=(Idx1<9)?Left_Hold_Fast[(Idx1+1)*Pixel_W-1 -: Pixel_W]:((Idx1<18)?Right_Hold_Fast[(Idx1-8)*Pixel_W-1 -: Pixel_W]:0);
    wire [Pixel_W-1:0] Pix2=(Idx2<9)?Left_Hold_Fast[(Idx2+1)*Pixel_W-1 -: Pixel_W]:((Idx2<18)?Right_Hold_Fast[(Idx2-8)*Pixel_W-1 -: Pixel_W]:0);
    wire [Pixel_W-1:0] Pix3=(Idx3<9)?Left_Hold_Fast[(Idx3+1)*Pixel_W-1 -: Pixel_W]:((Idx3<18)?Right_Hold_Fast[(Idx3-8)*Pixel_W-1 -: Pixel_W]:0);

    wire signed [Kernel_W-1:0] Coef0=(Idx0<9)?$signed(Kernel_Hold_Fast[(Idx0+1)*Kernel_W-1 -: Kernel_W]):((Idx0<18)?$signed(Kernel_Hold_Fast[(Idx0-8)*Kernel_W-1 -: Kernel_W]):0);
    wire signed [Kernel_W-1:0] Coef1=(Idx1<9)?$signed(Kernel_Hold_Fast[(Idx1+1)*Kernel_W-1 -: Kernel_W]):((Idx1<18)?$signed(Kernel_Hold_Fast[(Idx1-8)*Kernel_W-1 -: Kernel_W]):0);
    wire signed [Kernel_W-1:0] Coef2=(Idx2<9)?$signed(Kernel_Hold_Fast[(Idx2+1)*Kernel_W-1 -: Kernel_W]):((Idx2<18)?$signed(Kernel_Hold_Fast[(Idx2-8)*Kernel_W-1 -: Kernel_W]):0);
    wire signed [Kernel_W-1:0] Coef3=(Idx3<9)?$signed(Kernel_Hold_Fast[(Idx3+1)*Kernel_W-1 -: Kernel_W]):((Idx3<18)?$signed(Kernel_Hold_Fast[(Idx3-8)*Kernel_W-1 -: Kernel_W]):0);

    wire signed [16:0] Pix0_Ext=$signed({9'b0,Pix0});
    wire signed [16:0] Pix1_Ext=$signed({9'b0,Pix1});
    wire signed [16:0] Pix2_Ext=$signed({9'b0,Pix2});
    wire signed [16:0] Pix3_Ext=$signed({9'b0,Pix3});
    wire signed [16:0] Coef0_Ext=$signed({{9{Coef0[Kernel_W-1]}},Coef0});
    wire signed [16:0] Coef1_Ext=$signed({{9{Coef1[Kernel_W-1]}},Coef1});
    wire signed [16:0] Coef2_Ext=$signed({{9{Coef2[Kernel_W-1]}},Coef2});
    wire signed [16:0] Coef3_Ext=$signed({{9{Coef3[Kernel_W-1]}},Coef3});

    (* use_dsp="yes" *) wire signed [16:0] M0=Pix0_Ext*Coef0_Ext;
    (* use_dsp="yes" *) wire signed [16:0] M1=Pix1_Ext*Coef1_Ext;
    (* use_dsp="yes" *) wire signed [16:0] M2=Pix2_Ext*Coef2_Ext;
    (* use_dsp="yes" *) wire signed [16:0] M3=Pix3_Ext*Coef3_Ext;

    wire signed [Prod_W-1:0] P0=$signed(M0[15:0]);
    wire signed [Prod_W-1:0] P1=$signed(M1[15:0]);
    wire signed [Prod_W-1:0] P2=$signed(M2[15:0]);
    wire signed [Prod_W-1:0] P3=$signed(M3[15:0]);

    wire signed [Acc_W-1:0] E0={{(Acc_W-Prod_W){P0[Prod_W-1]}},P0};
    wire signed [Acc_W-1:0] E1={{(Acc_W-Prod_W){P1[Prod_W-1]}},P1};
    wire signed [Acc_W-1:0] E2={{(Acc_W-Prod_W){P2[Prod_W-1]}},P2};
    wire signed [Acc_W-1:0] E3={{(Acc_W-Prod_W){P3[Prod_W-1]}},P3};

    // -------------------------------------------------------------------------
    // Fast-domain 4-DSP MAC engine.
    // Five fast cycles evaluate all 18 products for two adjacent windows.
    // -------------------------------------------------------------------------
    reg signed [Acc_W-1:0] Result_A_Fifo [0:3];
    reg signed [Acc_W-1:0] Result_B_Fifo [0:3];

    localparam integer FIFO_AW = 2;
    localparam integer FIFO_PW = FIFO_AW + 1;
    reg [FIFO_PW-1:0] Fifo_WBin, Fifo_WGray;
    reg [FIFO_PW-1:0] Fifo_RBin, Fifo_RGray;
    (* ASYNC_REG="TRUE" *) reg [FIFO_PW-1:0] Fifo_RGray_M1, Fifo_RGray_M2;
    (* ASYNC_REG="TRUE" *) reg [FIFO_PW-1:0] Fifo_WGray_M1, Fifo_WGray_M2;

    wire [FIFO_PW-1:0] Fifo_WBin_Next = Fifo_WBin + 1'b1;
    wire [FIFO_PW-1:0] Fifo_WGray_Next = (Fifo_WBin_Next >> 1) ^ Fifo_WBin_Next;
    wire [FIFO_PW-1:0] Fifo_RBin_Next = Fifo_RBin + 1'b1;
    wire [FIFO_PW-1:0] Fifo_RGray_Next = (Fifo_RBin_Next >> 1) ^ Fifo_RBin_Next;

    wire Fifo_Full = (Fifo_WGray_Next ==
                      {~Fifo_RGray_M2[FIFO_PW-1:FIFO_PW-2],
                       Fifo_RGray_M2[FIFO_PW-3:0]});
    wire Fifo_Empty = (Fifo_RGray == Fifo_WGray_M2);

    always @(posedge Clk_Fast or negedge Rst_N) begin
        if (!Rst_N) begin
            Fifo_RGray_M1 <= 0;
            Fifo_RGray_M2 <= 0;
        end else if (!Fast_Locked) begin
            Fifo_RGray_M1 <= 0;
            Fifo_RGray_M2 <= 0;
        end else begin
            Fifo_RGray_M1 <= Fifo_RGray;
            Fifo_RGray_M2 <= Fifo_RGray_M1;
        end
    end

    always @(posedge Clk_Sys or negedge Rst_N) begin
        if (!Rst_N) begin
            Fifo_WGray_M1 <= 0;
            Fifo_WGray_M2 <= 0;
        end else begin
            Fifo_WGray_M1 <= Fifo_WGray;
            Fifo_WGray_M2 <= Fifo_WGray_M1;
        end
    end

    integer J;
    always @(posedge Clk_Fast or negedge Rst_N) begin
        if (!Rst_N) begin
            Running <= 0;
            Finish_Pending <= 0;
            Slot <= 0;
            Acc_A <= 0;
            Acc_B <= 0;
            Left_Hold_Fast <= 0;
            Right_Hold_Fast <= 0;
            Kernel_Hold_Fast <= 0;
            Fifo_WBin <= 0;
            Fifo_WGray <= 0;
            for (J=0; J<4; J=J+1) begin
                Result_A_Fifo[J] <= 0;
                Result_B_Fifo[J] <= 0;
            end
        end else if (!Fast_Locked) begin
            Running <= 0;
            Finish_Pending <= 0;
            Fifo_WBin <= 0;
            Fifo_WGray <= 0;
        end else if (Req_Fifo_Rd_En) begin
            // FWFT exposes the oldest request on dout before rd_en. Capture
            // it on this edge, then the FIFO advances to the next request.
            Left_Hold_Fast <= Req_Fifo_Dout[K*K*Pixel_W-1:0];
            Right_Hold_Fast <= Req_Fifo_Dout[2*K*K*Pixel_W-1:K*K*Pixel_W];
            Kernel_Hold_Fast <= Req_Fifo_Dout[REQ_W-1:2*K*K*Pixel_W];
            Running <= 1;
            Slot <= 0;
            Acc_A <= 0;
            Acc_B <= 0;
        end else if (Running) begin
            case (Slot)
                0,1: Acc_A <= Acc_A + E0 + E1 + E2 + E3;
                2: begin
                    Acc_A <= Acc_A + E0;
                    Acc_B <= Acc_B + E1 + E2 + E3;
                end
                3: Acc_B <= Acc_B + E0 + E1 + E2 + E3;
                4: begin
                    if (!Fifo_Full) begin
                        Result_A_Fifo[Fifo_WBin[FIFO_AW-1:0]] <= Acc_A;
                        Result_B_Fifo[Fifo_WBin[FIFO_AW-1:0]] <= Acc_B + E0 + E1;
                        Fifo_WBin <= Fifo_WBin_Next;
                        Fifo_WGray <= Fifo_WGray_Next;
                        Running <= 0;
                    end else begin
                        Finish_Pending <= 1;
                    end
                end
                default: Running <= 0;
            endcase
            if (Slot!=4) Slot <= Slot+1'b1;
        end else if (Finish_Pending && !Fifo_Full) begin
            Result_A_Fifo[Fifo_WBin[FIFO_AW-1:0]] <= Acc_A;
            Result_B_Fifo[Fifo_WBin[FIFO_AW-1:0]] <= Acc_B + E0 + E1;
            Fifo_WBin <= Fifo_WBin_Next;
            Fifo_WGray <= Fifo_WGray_Next;
            Finish_Pending <= 0;
            Running <= 0;
        end
    end

    // -------------------------------------------------------------------------
    // System-domain result FIFO consumer.
    // -------------------------------------------------------------------------
    always @(posedge Clk_Sys or negedge Rst_N) begin
        if (!Rst_N) begin
            Fifo_RBin <= 0;
            Fifo_RGray <= 0;
            Valid_Out <= 0;
            Left_Acc_Out <= 0;
            Right_Acc_Out <= 0;
        end else begin
            Valid_Out <= 0;
            if (!Fifo_Empty && Out_Rd_En) begin
                Left_Acc_Out <= Result_A_Fifo[Fifo_RBin[FIFO_AW-1:0]];
                Right_Acc_Out <= Result_B_Fifo[Fifo_RBin[FIFO_AW-1:0]];
                Fifo_RBin <= Fifo_RBin_Next;
                Fifo_RGray <= Fifo_RGray_Next;
                Valid_Out <= 1;
            end
        end
    end
endmodule

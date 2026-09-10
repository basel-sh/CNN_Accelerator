//==============================================================================
// mac_pair_mp4.v | Resource-optimized exact 2-output/cycle MAC
//
// Four shared DSP multipliers run at 120 MHz while the system interface runs
// at 20 MHz. The 18 exact products required by two adjacent arbitrary 3x3
// convolutions are scheduled across five fast cycles.
//==============================================================================
module mac_pair_mp4 #(
    parameter Pixel_W  = 8,
    parameter Kernel_W = 8,
    parameter Acc_W    = 20,
    parameter K        = 3
)(
    input  wire                               Clk_Sys,
    input  wire                               Clk_Fast,
    input  wire                               Rst_N,
    input  wire                               Fast_Locked,
    input  wire                               Valid_In,
    input  wire [K*K*Pixel_W-1:0]             Left_Window_Flat,
    input  wire [K*K*Pixel_W-1:0]             Right_Window_Flat,
    input  wire signed [K*K*Kernel_W-1:0]     Kernel_Flat,
    output reg                                Valid_Out,
    output reg signed [Acc_W-1:0]             Left_Acc_Out,
    output reg signed [Acc_W-1:0]             Right_Acc_Out
);
    localparam integer N      = K*K;
    localparam integer Prod_W = 16;

    // System-domain transaction holding registers.
    reg [K*K*Pixel_W-1:0] Left_Hold_Sys;
    reg [K*K*Pixel_W-1:0] Right_Hold_Sys;
    reg signed [K*K*Kernel_W-1:0] Kernel_Hold_Sys;
    reg Req_Toggle_Sys;

    always @(posedge Clk_Sys or negedge Rst_N) begin
        if (!Rst_N) begin
            Left_Hold_Sys   <= {K*K*Pixel_W{1'b0}};
            Right_Hold_Sys  <= {K*K*Pixel_W{1'b0}};
            Kernel_Hold_Sys <= {K*K*Kernel_W{1'b0}};
            Req_Toggle_Sys  <= 1'b0;
        end else if (Valid_In) begin
            Left_Hold_Sys   <= Left_Window_Flat;
            Right_Hold_Sys  <= Right_Window_Flat;
            Kernel_Hold_Sys <= Kernel_Flat;
            Req_Toggle_Sys  <= ~Req_Toggle_Sys;
        end
    end

    // Request synchronizer into the fast clock domain. Req_Seen is owned only
    // by the engine state machine below.
    reg Req_M1, Req_M2, Req_Seen;
    reg Done_Toggle_Fast;
    always @(posedge Clk_Fast or negedge Rst_N) begin
        if (!Rst_N) begin
            Req_M1 <= 1'b0;
            Req_M2 <= 1'b0;
        end else if (!Fast_Locked) begin
            Req_M1 <= 1'b0;
            Req_M2 <= 1'b0;
        end else begin
            Req_M1 <= Req_Toggle_Sys;
            Req_M2 <= Req_M1;
        end
    end
    wire New_Request = Req_M2 ^ Req_Seen;

    reg [K*K*Pixel_W-1:0] Left_Hold_Fast;
    reg [K*K*Pixel_W-1:0] Right_Hold_Fast;
    reg signed [K*K*Kernel_W-1:0] Kernel_Hold_Fast;

    reg [2:0] Slot;
    reg Running;
    reg signed [Acc_W-1:0] Acc_A, Acc_B;
    reg signed [Acc_W-1:0] Final_A_Fast, Final_B_Fast;

    // Product indices 0..8 belong to the left output; 9..17 belong to the
    // right output. Slots 0..4 issue 4,4,4,4,2 products respectively.
    wire [4:0] Idx0 = (Slot * 4) + 0;
    wire [4:0] Idx1 = (Slot * 4) + 1;
    wire [4:0] Idx2 = (Slot * 4) + 2;
    wire [4:0] Idx3 = (Slot * 4) + 3;

    wire [Pixel_W-1:0] Pix0 = (Idx0 < 9) ?
        Left_Hold_Fast[(Idx0+1)*Pixel_W-1 -: Pixel_W] :
        ((Idx0 < 18) ? Right_Hold_Fast[(Idx0-9+1)*Pixel_W-1 -: Pixel_W] : {Pixel_W{1'b0}});
    wire [Pixel_W-1:0] Pix1 = (Idx1 < 9) ?
        Left_Hold_Fast[(Idx1+1)*Pixel_W-1 -: Pixel_W] :
        ((Idx1 < 18) ? Right_Hold_Fast[(Idx1-9+1)*Pixel_W-1 -: Pixel_W] : {Pixel_W{1'b0}});
    wire [Pixel_W-1:0] Pix2 = (Idx2 < 9) ?
        Left_Hold_Fast[(Idx2+1)*Pixel_W-1 -: Pixel_W] :
        ((Idx2 < 18) ? Right_Hold_Fast[(Idx2-9+1)*Pixel_W-1 -: Pixel_W] : {Pixel_W{1'b0}});
    wire [Pixel_W-1:0] Pix3 = (Idx3 < 9) ?
        Left_Hold_Fast[(Idx3+1)*Pixel_W-1 -: Pixel_W] :
        ((Idx3 < 18) ? Right_Hold_Fast[(Idx3-9+1)*Pixel_W-1 -: Pixel_W] : {Pixel_W{1'b0}});

    wire signed [Kernel_W-1:0] Coef0 = (Idx0 < 9) ?
        $signed(Kernel_Hold_Fast[(Idx0+1)*Kernel_W-1 -: Kernel_W]) :
        ((Idx0 < 18) ? $signed(Kernel_Hold_Fast[(Idx0-9+1)*Kernel_W-1 -: Kernel_W]) : {Kernel_W{1'b0}});
    wire signed [Kernel_W-1:0] Coef1 = (Idx1 < 9) ?
        $signed(Kernel_Hold_Fast[(Idx1+1)*Kernel_W-1 -: Kernel_W]) :
        ((Idx1 < 18) ? $signed(Kernel_Hold_Fast[(Idx1-9+1)*Kernel_W-1 -: Kernel_W]) : {Kernel_W{1'b0}});
    wire signed [Kernel_W-1:0] Coef2 = (Idx2 < 9) ?
        $signed(Kernel_Hold_Fast[(Idx2+1)*Kernel_W-1 -: Kernel_W]) :
        ((Idx2 < 18) ? $signed(Kernel_Hold_Fast[(Idx2-9+1)*Kernel_W-1 -: Kernel_W]) : {Kernel_W{1'b0}});
    wire signed [Kernel_W-1:0] Coef3 = (Idx3 < 9) ?
        $signed(Kernel_Hold_Fast[(Idx3+1)*Kernel_W-1 -: Kernel_W]) :
        ((Idx3 < 18) ? $signed(Kernel_Hold_Fast[(Idx3-9+1)*Kernel_W-1 -: Kernel_W]) : {Kernel_W{1'b0}});

    // Explicit 17-bit multiplication context prevents Verilog expression-size
    // ambiguity. The mathematical range fits exactly in the low 16 bits.
    (* use_dsp = "yes" *) wire signed [16:0] M0 = $signed({1'b0, Pix0}) * Coef0;
    (* use_dsp = "yes" *) wire signed [16:0] M1 = $signed({1'b0, Pix1}) * Coef1;
    (* use_dsp = "yes" *) wire signed [16:0] M2 = $signed({1'b0, Pix2}) * Coef2;
    (* use_dsp = "yes" *) wire signed [16:0] M3 = $signed({1'b0, Pix3}) * Coef3;

    wire signed [Prod_W-1:0] P0 = M0[15:0];
    wire signed [Prod_W-1:0] P1 = M1[15:0];
    wire signed [Prod_W-1:0] P2 = M2[15:0];
    wire signed [Prod_W-1:0] P3 = M3[15:0];

    wire signed [Acc_W-1:0] E0 = {{(Acc_W-Prod_W){P0[Prod_W-1]}}, P0};
    wire signed [Acc_W-1:0] E1 = {{(Acc_W-Prod_W){P1[Prod_W-1]}}, P1};
    wire signed [Acc_W-1:0] E2 = {{(Acc_W-Prod_W){P2[Prod_W-1]}}, P2};
    wire signed [Acc_W-1:0] E3 = {{(Acc_W-Prod_W){P3[Prod_W-1]}}, P3};

    always @(posedge Clk_Fast or negedge Rst_N) begin
        if (!Rst_N) begin
            Running          <= 1'b0;
            Slot             <= 3'd0;
            Req_Seen         <= 1'b0;
            Done_Toggle_Fast <= 1'b0;
            Acc_A            <= {Acc_W{1'b0}};
            Acc_B            <= {Acc_W{1'b0}};
            Final_A_Fast     <= {Acc_W{1'b0}};
            Final_B_Fast     <= {Acc_W{1'b0}};
        end else if (!Fast_Locked) begin
            Running          <= 1'b0;
            Req_Seen         <= Req_M2;
            Done_Toggle_Fast <= 1'b0;
        end else if (New_Request && !Running) begin
            Left_Hold_Fast   <= Left_Hold_Sys;
            Right_Hold_Fast  <= Right_Hold_Sys;
            Kernel_Hold_Fast <= Kernel_Hold_Sys;
            Req_Seen         <= Req_M2;
            Running          <= 1'b1;
            Slot             <= 3'd0;
            Acc_A            <= {Acc_W{1'b0}};
            Acc_B            <= {Acc_W{1'b0}};
        end else if (Running) begin
            if (Slot == 3'd0 || Slot == 3'd1) begin
                Acc_A <= Acc_A + E0 + E1 + E2 + E3;
            end else if (Slot == 3'd2) begin
                Acc_A <= Acc_A + E0;
                Acc_B <= Acc_B + E1 + E2 + E3;
            end else if (Slot == 3'd3) begin
                Acc_B <= Acc_B + E0 + E1 + E2 + E3;
            end else begin
                // Slot 4 contains right products 7 and 8 only.
                Final_A_Fast     <= Acc_A;
                Final_B_Fast     <= Acc_B + E0 + E1;
                Running          <= 1'b0;
                Done_Toggle_Fast <= ~Done_Toggle_Fast;
            end
            if (Slot != 3'd4)
                Slot <= Slot + 1'b1;
        end
    end

    // Return result and valid pulse to the system domain.
    reg Done_M1, Done_M2, Done_Seen;
    always @(posedge Clk_Sys or negedge Rst_N) begin
        if (!Rst_N) begin
            Done_M1       <= 1'b0;
            Done_M2       <= 1'b0;
            Done_Seen     <= 1'b0;
            Valid_Out     <= 1'b0;
            Left_Acc_Out  <= {Acc_W{1'b0}};
            Right_Acc_Out <= {Acc_W{1'b0}};
        end else begin
            Done_M1   <= Done_Toggle_Fast;
            Done_M2   <= Done_M1;
            Valid_Out <= 1'b0;
            if (Done_M2 ^ Done_Seen) begin
                Done_Seen     <= Done_M2;
                Left_Acc_Out  <= Final_A_Fast;
                Right_Acc_Out <= Final_B_Fast;
                Valid_Out     <= 1'b1;
            end
        end
    end
endmodule

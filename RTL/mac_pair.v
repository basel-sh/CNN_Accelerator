//==============================================================================
// mac_pair.v | Exact 2-output/cycle 3x3 MAC
//
// IMPORTANT: adjacent convolution windows overlap in INPUT PIXELS, but for a
// general programmable kernel those shared pixels are multiplied by different
// kernel coefficients after a one-pixel shift. Therefore an exact arbitrary
// 3x3 kernel still requires 18 pixel*coefficient products for two outputs.
// The overlap is exploited in the WINDOW/MEMORY dataflow, not by incorrectly
// reusing products with different coefficients.
//
// Pipeline latency: 2 cycles from Valid_In to Valid_Out.
//==============================================================================
module mac_pair #(
    parameter Pixel_W  = 8,
    parameter Kernel_W = 8,
    parameter Acc_W    = 20,
    parameter K        = 3
)(
    input wire                               Clk,
    input wire                               Rst_N,
    input wire                               Valid_In,
    input wire [K*K*Pixel_W-1:0]             Left_Window_Flat,
    input wire [K*K*Pixel_W-1:0]             Right_Window_Flat,
    input wire signed [K*K*Kernel_W-1:0]     Kernel_Flat,
    output reg                               Valid_Out,
    output reg signed [Acc_W-1:0]            Left_Acc_Out,
    output reg signed [Acc_W-1:0]            Right_Acc_Out
);
    localparam integer N      = K*K;
    localparam integer Prod_W = Pixel_W + Kernel_W + 1;
    integer I;

    // Exact products for both adjacent windows: 9 + 9 = 18 products.
    reg signed [Prod_W-1:0] Left_Prod_Comb  [0:N-1];
    reg signed [Prod_W-1:0] Right_Prod_Comb [0:N-1];

    always @(*) begin
        for (I=0; I<N; I=I+1) begin
            Left_Prod_Comb[I] =
                $signed({1'b0, Left_Window_Flat[(I+1)*Pixel_W-1 -: Pixel_W]}) *
                $signed(Kernel_Flat[(I+1)*Kernel_W-1 -: Kernel_W]);
            Right_Prod_Comb[I] =
                $signed({1'b0, Right_Window_Flat[(I+1)*Pixel_W-1 -: Pixel_W]}) *
                $signed(Kernel_Flat[(I+1)*Kernel_W-1 -: Kernel_W]);
        end
    end

    // Stage 1: register products for both output lanes.
    reg signed [Prod_W-1:0] Left_Prod_Reg  [0:N-1];
    reg signed [Prod_W-1:0] Right_Prod_Reg [0:N-1];
    reg Valid_D1;

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Valid_D1 <= 1'b0;
            for (I=0; I<N; I=I+1) begin
                Left_Prod_Reg[I]  <= {Prod_W{1'b0}};
                Right_Prod_Reg[I] <= {Prod_W{1'b0}};
            end
        end else begin
            Valid_D1 <= Valid_In;
            for (I=0; I<N; I=I+1) begin
                Left_Prod_Reg[I]  <= Left_Prod_Comb[I];
                Right_Prod_Reg[I] <= Right_Prod_Comb[I];
            end
        end
    end

    // Explicit signed extension to Acc_W before the balanced reductions.
    wire signed [Acc_W-1:0] L0 = {{(Acc_W-Prod_W){Left_Prod_Reg[0][Prod_W-1]}}, Left_Prod_Reg[0]};
    wire signed [Acc_W-1:0] L1 = {{(Acc_W-Prod_W){Left_Prod_Reg[1][Prod_W-1]}}, Left_Prod_Reg[1]};
    wire signed [Acc_W-1:0] L2 = {{(Acc_W-Prod_W){Left_Prod_Reg[2][Prod_W-1]}}, Left_Prod_Reg[2]};
    wire signed [Acc_W-1:0] L3 = {{(Acc_W-Prod_W){Left_Prod_Reg[3][Prod_W-1]}}, Left_Prod_Reg[3]};
    wire signed [Acc_W-1:0] L4 = {{(Acc_W-Prod_W){Left_Prod_Reg[4][Prod_W-1]}}, Left_Prod_Reg[4]};
    wire signed [Acc_W-1:0] L5 = {{(Acc_W-Prod_W){Left_Prod_Reg[5][Prod_W-1]}}, Left_Prod_Reg[5]};
    wire signed [Acc_W-1:0] L6 = {{(Acc_W-Prod_W){Left_Prod_Reg[6][Prod_W-1]}}, Left_Prod_Reg[6]};
    wire signed [Acc_W-1:0] L7 = {{(Acc_W-Prod_W){Left_Prod_Reg[7][Prod_W-1]}}, Left_Prod_Reg[7]};
    wire signed [Acc_W-1:0] L8 = {{(Acc_W-Prod_W){Left_Prod_Reg[8][Prod_W-1]}}, Left_Prod_Reg[8]};

    wire signed [Acc_W-1:0] R0 = {{(Acc_W-Prod_W){Right_Prod_Reg[0][Prod_W-1]}}, Right_Prod_Reg[0]};
    wire signed [Acc_W-1:0] R1 = {{(Acc_W-Prod_W){Right_Prod_Reg[1][Prod_W-1]}}, Right_Prod_Reg[1]};
    wire signed [Acc_W-1:0] R2 = {{(Acc_W-Prod_W){Right_Prod_Reg[2][Prod_W-1]}}, Right_Prod_Reg[2]};
    wire signed [Acc_W-1:0] R3 = {{(Acc_W-Prod_W){Right_Prod_Reg[3][Prod_W-1]}}, Right_Prod_Reg[3]};
    wire signed [Acc_W-1:0] R4 = {{(Acc_W-Prod_W){Right_Prod_Reg[4][Prod_W-1]}}, Right_Prod_Reg[4]};
    wire signed [Acc_W-1:0] R5 = {{(Acc_W-Prod_W){Right_Prod_Reg[5][Prod_W-1]}}, Right_Prod_Reg[5]};
    wire signed [Acc_W-1:0] R6 = {{(Acc_W-Prod_W){Right_Prod_Reg[6][Prod_W-1]}}, Right_Prod_Reg[6]};
    wire signed [Acc_W-1:0] R7 = {{(Acc_W-Prod_W){Right_Prod_Reg[7][Prod_W-1]}}, Right_Prod_Reg[7]};
    wire signed [Acc_W-1:0] R8 = {{(Acc_W-Prod_W){Right_Prod_Reg[8][Prod_W-1]}}, Right_Prod_Reg[8]};

    wire signed [Acc_W-1:0] L01   = L0 + L1;
    wire signed [Acc_W-1:0] L23   = L2 + L3;
    wire signed [Acc_W-1:0] L45   = L4 + L5;
    wire signed [Acc_W-1:0] L67   = L6 + L7;
    wire signed [Acc_W-1:0] L0123 = L01 + L23;
    wire signed [Acc_W-1:0] L4567 = L45 + L67;
    wire signed [Acc_W-1:0] L_Sum = L0123 + L4567 + L8;

    wire signed [Acc_W-1:0] R01   = R0 + R1;
    wire signed [Acc_W-1:0] R23   = R2 + R3;
    wire signed [Acc_W-1:0] R45   = R4 + R5;
    wire signed [Acc_W-1:0] R67   = R6 + R7;
    wire signed [Acc_W-1:0] R0123 = R01 + R23;
    wire signed [Acc_W-1:0] R4567 = R45 + R67;
    wire signed [Acc_W-1:0] R_Sum = R0123 + R4567 + R8;

    // Stage 2: one-cycle output register for both lanes.
    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Valid_Out     <= 1'b0;
            Left_Acc_Out  <= {Acc_W{1'b0}};
            Right_Acc_Out <= {Acc_W{1'b0}};
        end else begin
            Valid_Out     <= Valid_D1;
            Left_Acc_Out  <= L_Sum;
            Right_Acc_Out <= R_Sum;
        end
    end
endmodule

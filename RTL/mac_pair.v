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

    // Generic N-term reduction (FIX 2026-09-12: the previous version hardcoded
    // this stage to exactly 9 terms (L0..L8 / R0..R8), so for any K != 3
    // (N != 9) it silently dropped every product past index 8 and produced
    // wrong sums with no error - confirmed by K=5 simulation (FUNC-07).
    // This loop-based reduction sums all N = K*K sign-extended products, so
    // it is correct for any K the window_generator_2px.v / kernel_memory.v
    // already generalize to.
    reg signed [Acc_W-1:0] L_Sum_Comb, R_Sum_Comb;
    integer J;
    always @(*) begin
        L_Sum_Comb = {Acc_W{1'b0}};
        R_Sum_Comb = {Acc_W{1'b0}};
        for (J = 0; J < N; J = J + 1) begin
            L_Sum_Comb = L_Sum_Comb + {{(Acc_W-Prod_W){Left_Prod_Reg[J][Prod_W-1]}}, Left_Prod_Reg[J]};
            R_Sum_Comb = R_Sum_Comb + {{(Acc_W-Prod_W){Right_Prod_Reg[J][Prod_W-1]}}, Right_Prod_Reg[J]};
        end
    end

    // Stage 2: one-cycle output register for both lanes.
    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Valid_Out     <= 1'b0;
            Left_Acc_Out  <= {Acc_W{1'b0}};
            Right_Acc_Out <= {Acc_W{1'b0}};
        end else begin
            Valid_Out     <= Valid_D1;
            Left_Acc_Out  <= L_Sum_Comb;
            Right_Acc_Out <= R_Sum_Comb;
        end
    end
endmodule

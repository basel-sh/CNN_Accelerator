//==============================================================================
// mac.v | Module: mac | Phase 6 - MAC Unit
// Multiplies each of the KxK unsigned window pixels by its signed Kernel_W
// coefficient and accumulates into a signed Acc_W result (registered,
// 1-cycle latency, Valid_In/Valid_Out paired).
//==============================================================================
module mac #(
    parameter Pixel_W  = 8,
    parameter Kernel_W = 8,
    parameter Acc_W    = 20,
    parameter K        = 3
)(
    input  wire                            Clk,
    input  wire                            Rst_N,
    input  wire                            Valid_In,
    input  wire [K*K*Pixel_W-1:0]          Window_Flat,
    input  wire signed [K*K*Kernel_W-1:0]  Kernel_Flat,
    output reg                             Valid_Out,
    output reg  signed [Acc_W-1:0]         Acc_Out
);
    integer I;
    reg signed [Pixel_W:0]           Pix_S  [0:K*K-1];   // zero-extended, +1 sign bit
    reg signed [Kernel_W-1:0]        Coef_S [0:K*K-1];
    reg signed [Pixel_W+Kernel_W:0]  Prod   [0:K*K-1];
    reg signed [Acc_W-1:0]           Sum_Comb;

    always @(*) begin
        Sum_Comb = {Acc_W{1'b0}};
        for (I = 0; I < K*K; I = I + 1) begin
            Pix_S[I]  = $signed({1'b0, Window_Flat[(I+1)*Pixel_W-1 -: Pixel_W]});
            Coef_S[I] = $signed(Kernel_Flat[(I+1)*Kernel_W-1 -: Kernel_W]);
            Prod[I]   = Pix_S[I] * Coef_S[I];
            Sum_Comb  = Sum_Comb + Prod[I];
        end
    end

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Valid_Out <= 1'b0;
            Acc_Out   <= {Acc_W{1'b0}};
        end else begin
            Valid_Out <= Valid_In;
            Acc_Out   <= Sum_Comb;
        end
    end
endmodule

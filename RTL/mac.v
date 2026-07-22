//==============================================================================
// File   : mac.v  |  Module: mac  |  Phase 6 - MAC Unit
// Multiplies each of the KxK unsigned window pixels by its corresponding
// signed KERNEL_W-bit kernel coefficient and accumulates into a signed
// ACC_W-bit result (registered, 1-cycle latency, valid_in/valid_out paired).
//==============================================================================
module mac #(
    parameter PIXEL_W  = 8,
    parameter KERNEL_W = 8,
    parameter ACC_W    = 20,
    parameter K        = 3
)(
    input  wire                            clk,
    input  wire                            rst_n,
    input  wire                            valid_in,
    input  wire [K*K*PIXEL_W-1:0]          window_flat,
    input  wire signed [K*K*KERNEL_W-1:0]  kernel_flat,
    output reg                             valid_out,
    output reg  signed [ACC_W-1:0]         acc_out
);
    integer i;
    reg signed [PIXEL_W:0]              pix_s   [0:K*K-1];   // zero-extended, 1 extra bit for sign
    reg signed [KERNEL_W-1:0]            coef_s  [0:K*K-1];
    reg signed [PIXEL_W+KERNEL_W:0]       prod    [0:K*K-1];
    reg signed [ACC_W-1:0]               sum_comb;

    always @(*) begin
        sum_comb = {ACC_W{1'b0}};
        for (i = 0; i < K*K; i = i + 1) begin
            pix_s[i]  = $signed({1'b0, window_flat[(i+1)*PIXEL_W-1 -: PIXEL_W]});
            coef_s[i] = $signed(kernel_flat[(i+1)*KERNEL_W-1 -: KERNEL_W]);
            prod[i]   = pix_s[i] * coef_s[i];
            sum_comb  = sum_comb + prod[i];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            acc_out   <= {ACC_W{1'b0}};
        end else begin
            valid_out <= valid_in;
            acc_out   <= sum_comb;
        end
    end
endmodule

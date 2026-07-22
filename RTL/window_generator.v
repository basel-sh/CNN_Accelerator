//==============================================================================
// File   : window_generator.v  |  Module: window_generator  |  Phase 5
// Consumes K row taps (one per output row of the window) and maintains K
// independent K-deep column shift registers, forming the full KxK sliding
// convolution window (stride 1). window[row][col], row=0 (top/oldest) to
// K-1 (bottom/current); col=0 (left/oldest) to K-1 (right/current).
//==============================================================================
module window_generator #(
    parameter PIXEL_W = 8,
    parameter K       = 3
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     shift_en,
    input  wire [K*PIXEL_W-1:0]     row_taps_flat,
    output wire [K*K*PIXEL_W-1:0]   window_flat
);
    wire [PIXEL_W-1:0] row_tap [0:K-1];
    genvar r, c;
    generate
        for (r = 0; r < K; r = r + 1) begin : UNPACK_TAPS
            assign row_tap[r] = row_taps_flat[(r+1)*PIXEL_W-1 -: PIXEL_W];
        end
    endgenerate

    reg [PIXEL_W-1:0] col_reg [0:K-1][0:K-1];
    integer i, j;

    generate
        for (r = 0; r < K; r = r + 1) begin : ROW
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (j = 0; j < K; j = j + 1)
                        col_reg[r][j] <= {PIXEL_W{1'b0}};
                end else if (shift_en) begin
                    for (j = 0; j < K-1; j = j + 1)
                        col_reg[r][j] <= col_reg[r][j+1];
                    col_reg[r][K-1] <= row_tap[r];
                end
            end
        end
    endgenerate

    generate
        for (r = 0; r < K; r = r + 1) begin : PACK_ROW
            for (c = 0; c < K; c = c + 1) begin : PACK_COL
                localparam integer G = r*K + c;
                assign window_flat[(G+1)*PIXEL_W-1 -: PIXEL_W] = col_reg[r][c];
            end
        end
    endgenerate
endmodule

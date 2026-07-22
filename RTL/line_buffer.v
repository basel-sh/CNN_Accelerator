//==============================================================================
// File   : line_buffer.v  |  Module: line_buffer  |  Phase 4 - Line Buffer
// Produces K row-synchronous "taps" from a single streamed pixel input, using
// K-1 chained shift-register delay lines (depth = IMG_W), giving each stage
// exactly one image-row of delay.
//
// tap[K-1] = current pixel (no delay)
// tap[K-2] = pixel from one row above (delayed IMG_W cycles)
// tap[0]   = pixel from (K-1) rows above
//
// NOTE: an earlier version of this module built the delay lines from ram.v
// using a shared read/write address (a common BRAM-based line-buffer trick).
// Icarus Verilog simulated that same-cycle same-address read/write
// inconsistently (see Reports/ for the Phase 9 sim debug notes), so this
// scaffold uses plain flip-flop shift registers instead, which are
// unambiguous in any simulator. Re-introducing a BRAM-backed delay line is a
// tracked Phase 10 (Optimization) resource-usage improvement, using a true
// dual-port RAM with distinct, never-equal read/write addresses.
//==============================================================================
module line_buffer #(
    parameter PIXEL_W = 8,
    parameter IMG_W   = 32,
    parameter K       = 3
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        shift_en,
    input  wire [PIXEL_W-1:0]          pixel_in,
    output wire [K*PIXEL_W-1:0]        row_taps_flat
);
    localparam DEPTH = IMG_W;

    wire [PIXEL_W-1:0] tap [0:K-1];
    assign tap[K-1] = pixel_in;

    genvar g;
    generate
        for (g = 0; g < K-1; g = g + 1) begin : DELAY_STAGE
            reg  [PIXEL_W-1:0] chain [0:DEPTH-1];
            integer k;
            wire [PIXEL_W-1:0] stage_in = (g == 0) ? pixel_in : tap[K-1-g];

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (k = 0; k < DEPTH; k = k + 1)
                        chain[k] <= {PIXEL_W{1'b0}};
                end else if (shift_en) begin
                    for (k = DEPTH-1; k > 0; k = k - 1)
                        chain[k] <= chain[k-1];
                    chain[0] <= stage_in;
                end
            end

            assign tap[K-2-g] = chain[DEPTH-1];
        end
    endgenerate

    generate
        for (g = 0; g < K; g = g + 1) begin : PACK
            assign row_taps_flat[(g+1)*PIXEL_W-1 -: PIXEL_W] = tap[g];
        end
    endgenerate
endmodule

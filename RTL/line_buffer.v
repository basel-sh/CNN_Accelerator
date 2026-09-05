//==============================================================================
// line_buffer.v | Module: line_buffer | Phase 4 - Line Buffer
// Produces K row-synchronous "taps" from one streamed pixel, using K-1
// chained shift-register delay lines (depth = Img_W), one image-row of
// delay per stage.
//
// Tap[K-1] = current pixel (no delay)
// Tap[K-2] = pixel from one row above (delayed Img_W cycles)
// Tap[0]   = pixel from (K-1) rows above
//
// NOTE: a RAM-based version of this delay line hit a same-cycle same-address
// simulator inconsistency in Icarus Verilog (see Documentation/
// VerificationResults.md), so this uses plain flip-flop shift registers
// instead - unambiguous everywhere. A BRAM-backed rewrite is a tracked
// Phase 10 resource-usage improvement.
//==============================================================================
module line_buffer #(
    parameter Pixel_W = 8,
    parameter Img_W   = 32,
    parameter K       = 3
)(
    input  wire                        Clk,
    input  wire                        Rst_N,
    input  wire                        Shift_En,
    input  wire [Pixel_W-1:0]          Pixel_In,
    output wire [K*Pixel_W-1:0]        Row_Taps_Flat
);
    localparam Depth = Img_W;

    wire [Pixel_W-1:0] Tap [0:K-1];
    assign Tap[K-1] = Pixel_In;

    genvar G;
    generate
        for (G = 0; G < K-1; G = G + 1) begin : Delay_Stage
            reg  [Pixel_W-1:0] Chain [0:Depth-1];
            // NOTE: kept lowercase - an uppercase "K" here would shadow the
            // module parameter K of the same name.
            integer k;
            wire [Pixel_W-1:0] Stage_In = (G == 0) ? Pixel_In : Tap[K-1-G];

            always @(posedge Clk) begin  // synchronous reset - Chain[] feeds the image_memory RAMB's output register chain (RBOR-1 fix)
                if (!Rst_N) begin
                    for (k = 0; k < Depth; k = k + 1)
                        Chain[k] <= {Pixel_W{1'b0}};
                end else if (Shift_En) begin
                    for (k = Depth-1; k > 0; k = k - 1)
                        Chain[k] <= Chain[k-1];
                    Chain[0] <= Stage_In;
                end
            end

            assign Tap[K-2-G] = Chain[Depth-1];
        end
    endgenerate

    generate
        for (G = 0; G < K; G = G + 1) begin : Pack
            assign Row_Taps_Flat[(G+1)*Pixel_W-1 -: Pixel_W] = Tap[G];
        end
    endgenerate
endmodule

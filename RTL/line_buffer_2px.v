//==============================================================================
// line_buffer_2px.v | Two-pixel-per-clock line buffer
//
// Accepts adjacent pixels A/B every cycle and produces the three row taps for
// both pixels. Each delay line is advanced twice per clock. The combinational
// tap-B path uses the one-position-newer entry (Chain[Depth-2]) so the two
// taps correspond to adjacent source columns.
//==============================================================================
module line_buffer_2px #(
    parameter Pixel_W = 8,
    parameter Img_W   = 32,
    parameter K       = 3
)(
    input  wire                     Clk,
    input  wire                     Rst_N,
    input  wire                     Shift_En,
    input  wire [Pixel_W-1:0]       Pixel_A,
    input  wire [Pixel_W-1:0]       Pixel_B,
    output wire [K*Pixel_W-1:0]     Row_Taps_A_Flat,
    output wire [K*Pixel_W-1:0]     Row_Taps_B_Flat
);
    localparam integer Depth = Img_W;

    wire [Pixel_W-1:0] Tap_A [0:K-1];
    wire [Pixel_W-1:0] Tap_B [0:K-1];
    assign Tap_A[K-1] = Pixel_A;
    assign Tap_B[K-1] = Pixel_B;

    genvar G;
    generate
        for (G = 0; G < K-1; G = G + 1) begin : Delay_Stage
            reg [Pixel_W-1:0] Chain [0:Depth-1];
            integer I;

            // A is the value at the current source column; B is the next
            // source column. Before this cycle's two shifts, these are the
            // last two relevant positions in the delay line.
            assign Tap_A[K-2-G] = Chain[Depth-1];
            assign Tap_B[K-2-G] = Chain[Depth-2];

            wire [Pixel_W-1:0] Stage_A = (G == 0) ? Pixel_A : Tap_A[K-1-G];
            wire [Pixel_W-1:0] Stage_B = (G == 0) ? Pixel_B : Tap_B[K-1-G];

            always @(posedge Clk) begin
                if (!Rst_N) begin
                    for (I = 0; I < Depth; I = I + 1)
                        Chain[I] <= {Pixel_W{1'b0}};
                end else if (Shift_En) begin
                    for (I = Depth-1; I >= 2; I = I - 1)
                        Chain[I] <= Chain[I-2];
                    Chain[1] <= Stage_A;
                    Chain[0] <= Stage_B;
                end
            end
        end
    endgenerate

    generate
        for (G = 0; G < K; G = G + 1) begin : Pack
            assign Row_Taps_A_Flat[(G+1)*Pixel_W-1 -: Pixel_W] = Tap_A[G];
            assign Row_Taps_B_Flat[(G+1)*Pixel_W-1 -: Pixel_W] = Tap_B[G];
        end
    endgenerate
endmodule

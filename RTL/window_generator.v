//==============================================================================
// window_generator.v | Module: window_generator | Phase 5 - Window Generator
// Consumes K row taps and maintains K independent K-deep column shift
// registers, forming the full KxK sliding convolution window (stride 1).
// Window[row][col]: row 0 = top/oldest .. K-1 = bottom/current;
//                    col 0 = left/oldest .. K-1 = right/current.
//==============================================================================
module window_generator #(
    parameter Pixel_W = 8,
    parameter K       = 3
)(
    input  wire                     Clk,
    input  wire                     Rst_N,
    input  wire                     Shift_En,
    input  wire [K*Pixel_W-1:0]     Row_Taps_Flat,
    output wire [K*K*Pixel_W-1:0]   Window_Flat
);
    wire [Pixel_W-1:0] Row_Tap [0:K-1];
    genvar R, C;
    generate
        for (R = 0; R < K; R = R + 1) begin : Unpack_Taps
            assign Row_Tap[R] = Row_Taps_Flat[(R+1)*Pixel_W-1 -: Pixel_W];
        end
    endgenerate

    reg [Pixel_W-1:0] Col_Reg [0:K-1][0:K-1];
    integer I, J;

    generate
        for (R = 0; R < K; R = R + 1) begin : Row
            always @(posedge Clk or negedge Rst_N) begin
                if (!Rst_N) begin
                    for (J = 0; J < K; J = J + 1)
                        Col_Reg[R][J] <= {Pixel_W{1'b0}};
                end else if (Shift_En) begin
                    for (J = 0; J < K-1; J = J + 1)
                        Col_Reg[R][J] <= Col_Reg[R][J+1];
                    Col_Reg[R][K-1] <= Row_Tap[R];
                end
            end
        end
    endgenerate

    generate
        for (R = 0; R < K; R = R + 1) begin : Pack_Row
            for (C = 0; C < K; C = C + 1) begin : Pack_Col
                localparam integer G = R*K + C;
                assign Window_Flat[(G+1)*Pixel_W-1 -: Pixel_W] = Col_Reg[R][C];
            end
        end
    endgenerate
endmodule

//==============================================================================
// window_generator_2px.v | Two adjacent KxK windows per clock
//==============================================================================
module window_generator_2px #(
    parameter Pixel_W = 8,
    parameter K       = 3
)(
    input  wire                     Clk,
    input  wire                     Rst_N,
    input  wire                     Shift_En,
    input  wire [K*Pixel_W-1:0]     Row_Taps_A_Flat,
    input  wire [K*Pixel_W-1:0]     Row_Taps_B_Flat,
    output reg  [K*K*Pixel_W-1:0]   Window_A_Flat,
    output reg  [K*K*Pixel_W-1:0]   Window_B_Flat
);
    wire [Pixel_W-1:0] Tap_A [0:K-1];
    wire [Pixel_W-1:0] Tap_B [0:K-1];
    genvar R;
    generate
        for (R=0; R<K; R=R+1) begin : Unpack
            assign Tap_A[R] = Row_Taps_A_Flat[(R+1)*Pixel_W-1 -: Pixel_W];
            assign Tap_B[R] = Row_Taps_B_Flat[(R+1)*Pixel_W-1 -: Pixel_W];
        end
    endgenerate

    reg [Pixel_W-1:0] Col_Reg [0:K-1][0:K-1];
    reg [K*K*Pixel_W-1:0] Win_A_Comb;
    reg [K*K*Pixel_W-1:0] Win_B_Comb;
    integer I, J;

    always @(*) begin
        Win_A_Comb = {(K*K*Pixel_W){1'b0}};
        Win_B_Comb = {(K*K*Pixel_W){1'b0}};
        for (I=0; I<K; I=I+1) begin
            // Window A = current state shifted once.
            for (J=0; J<K-1; J=J+1)
                Win_A_Comb[(I*K+J+1)*Pixel_W-1 -: Pixel_W] = Col_Reg[I][J+1];
            Win_A_Comb[(I*K+K)*Pixel_W-1 -: Pixel_W] = Tap_A[I];

            // Window B = current state shifted twice: [old K-2, old K-1,
            // tap A, tap B] for K=3. For general K, the first K-2 columns
            // come from Col_Reg[*][2..K-1].
            for (J=0; J<K-2; J=J+1)
                Win_B_Comb[(I*K+J+1)*Pixel_W-1 -: Pixel_W] = Col_Reg[I][J+2];
            if (K >= 2)
                Win_B_Comb[(I*K+K-1)*Pixel_W-1 -: Pixel_W] = Tap_A[I];
            Win_B_Comb[(I*K+K)*Pixel_W-1 -: Pixel_W] = Tap_B[I];
        end
    end

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Window_A_Flat <= {(K*K*Pixel_W){1'b0}};
            Window_B_Flat <= {(K*K*Pixel_W){1'b0}};
            for (I=0; I<K; I=I+1)
                for (J=0; J<K; J=J+1)
                    Col_Reg[I][J] <= {Pixel_W{1'b0}};
        end else if (Shift_En) begin
            Window_A_Flat <= Win_A_Comb;
            Window_B_Flat <= Win_B_Comb;
            // Persistent state after the pair is the B window.
            for (I=0; I<K; I=I+1) begin
                for (J=0; J<K-2; J=J+1)
                    Col_Reg[I][J] <= Col_Reg[I][J+2];
                if (K >= 2)
                    Col_Reg[I][K-2] <= Tap_A[I];
                Col_Reg[I][K-1] <= Tap_B[I];
            end
        end
    end
endmodule

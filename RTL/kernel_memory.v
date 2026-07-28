//==============================================================================
// kernel_memory.v | Module: kernel_memory | Phase 3 - Memory Architecture
// Programmable signed Kernel_W-bit NxN kernel store. Loaded one coefficient
// at a time via (We, Windex, Wdata); exposes all K*K coefficients at once as
// a flattened bus (plain-Verilog-friendly "array" port).
//==============================================================================
module kernel_memory #(
    parameter K         = 3,
    parameter Kernel_W  = 8,
    parameter Idxw       = $clog2(K * K)
)(
    input  wire                              Clk,
    input  wire                              Rst_N,
    input  wire                              We,
    input  wire [Idxw-1:0]                   Windex,
    input  wire signed [Kernel_W-1:0]        Wdata,
    output wire signed [K*K*Kernel_W-1:0]    Kernel_Flat
);
    reg signed [Kernel_W-1:0] Coeff [0:K*K-1];
    integer I;

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            for (I = 0; I < K*K; I = I + 1)
                Coeff[I] <= {Kernel_W{1'b0}};
        end else if (We) begin
            Coeff[Windex] <= Wdata;
        end
    end

    genvar G;
    generate
        for (G = 0; G < K*K; G = G + 1) begin : Pack
            assign Kernel_Flat[(G+1)*Kernel_W-1 -: Kernel_W] = Coeff[G];
        end
    endgenerate
endmodule

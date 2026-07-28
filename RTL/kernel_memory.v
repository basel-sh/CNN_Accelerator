//==============================================================================
// File   : kernel_memory.v  |  Module: kernel_memory  |  Phase 3 - Memory Arch.
// Programmable signed KERNEL_W-bit NxN kernel coefficient store. Loaded one
// coefficient at a time via (we, windex, wdata); exposes all K*K coefficients
// simultaneously as a flattened bus (plain-Verilog-friendly "array" port).
//==============================================================================
module kernel_memory #(
    parameter K         = 3,
    parameter KERNEL_W  = 8,
    parameter IDXW      = $clog2(K * K)         // 4
)(
    input  wire                              clk,
    input  wire                              rst_n,
    input  wire                              we,
    input  wire [IDXW-1:0]                   windex,
    input  wire signed [KERNEL_W-1:0]        wdata,
    output wire signed [K*K*KERNEL_W-1:0]    kernel_flat
);
    reg signed [KERNEL_W-1:0] coeff [0:K*K-1];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < K*K; i = i + 1)
                coeff[i] <= {KERNEL_W{1'b0}};
        end else if (we) begin
            coeff[windex] <= wdata;
        end
    end

    genvar g;
    generate
        for (g = 0; g < K*K; g = g + 1) begin : PACK
            assign kernel_flat[(g+1)*KERNEL_W-1 -: KERNEL_W] = coeff[g];
        end
    endgenerate
endmodule

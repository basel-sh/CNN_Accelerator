//==============================================================================
// mac.v | Module: mac | Phase 6 - MAC Unit
// Multiplies each of the KxK unsigned window pixels by its signed Kernel_W
// coefficient and accumulates into a signed Acc_W result. Pipelined over two
// registered stages (multiply -> registered products -> balanced adder tree
// -> registered sum) to break up the long single-cycle multiply+accumulate
// chain that previously failed timing closure (WNS -7.500 ns @ 10 ns clock,
// caused by a 23-logic-level path: 9 multiplies feeding a serial 8-deep
// addition chain, all in one cycle).
//
// Fix applied:
//   1) Register the 9 products before summing (splits multiply from add,
//      halving the combinational path across two clock cycles instead of one).
//   2) Replace the old serial accumulation (Sum = Sum + Prod[i], 8 adds in a
//      row) with a balanced binary adder tree (ceil(log2(9)) = 4 levels
//      instead of 8), cutting carry-chain depth roughly in half again.
//
// Latency: 2 cycles now (was 1). Valid_In/Valid_Out remain paired, so
// top.v/output_buffer do not need any changes - they only ever consume
// Valid_Out together with Acc_Out, never assume a specific cycle count.
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
    localparam integer N      = K*K;
    localparam integer Prod_W = Pixel_W + Kernel_W + 1;

    // ---- elaboration-time helpers describing the adder-tree shape ----
    function integer f_clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            f_clog2 = 0;
            while (v > 0) begin
                f_clog2 = f_clog2 + 1;
                v = v >> 1;
            end
        end
    endfunction

    function integer f_lvl_count;
        input integer n;
        input integer lvl;
        integer c, l;
        begin
            c = n;
            for (l = 0; l < lvl; l = l + 1)
                c = (c + 1) / 2;
            f_lvl_count = c;
        end
    endfunction

    localparam integer LVLS = f_clog2(N);

    integer I;

    // ---- Stage A (combinational): unpack window/kernel taps and multiply ----
    reg signed [Pixel_W:0]    Pix_S     [0:N-1];  // zero-extended, +1 sign bit
    reg signed [Kernel_W-1:0] Coef_S    [0:N-1];
    reg signed [Prod_W-1:0]   Prod_Comb [0:N-1];

    always @(*) begin
        for (I = 0; I < N; I = I + 1) begin
            Pix_S[I]     = $signed({1'b0, Window_Flat[(I+1)*Pixel_W-1 -: Pixel_W]});
            Coef_S[I]    = $signed(Kernel_Flat[(I+1)*Kernel_W-1 -: Kernel_W]);
            Prod_Comb[I] = Pix_S[I] * Coef_S[I];
        end
    end

    // ---- Pipeline register: breaks multiply away from the add-tree ----
    reg signed [Prod_W-1:0] Prod_Reg [0:N-1];
    reg                     Valid_D1;

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Valid_D1 <= 1'b0;
            for (I = 0; I < N; I = I + 1)
                Prod_Reg[I] <= {Prod_W{1'b0}};
        end else begin
            Valid_D1 <= Valid_In;
            for (I = 0; I < N; I = I + 1)
                Prod_Reg[I] <= Prod_Comb[I];
        end
    end

    // ---- Stage B (combinational): balanced binary adder tree ----
    wire signed [Acc_W-1:0] Tree [0:LVLS][0:N-1];

    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : G_LVL0
            assign Tree[0][gi] = {{(Acc_W-Prod_W){Prod_Reg[gi][Prod_W-1]}}, Prod_Reg[gi]};
        end
    endgenerate

    genvar gl, gj;
    generate
        for (gl = 1; gl <= LVLS; gl = gl + 1) begin : G_LVL
            localparam integer PREV_CNT = f_lvl_count(N, gl-1);
            localparam integer CUR_CNT  = f_lvl_count(N, gl);
            for (gj = 0; gj < CUR_CNT; gj = gj + 1) begin : G_PAIR
                if (2*gj+1 < PREV_CNT) begin : G_SUM
                    assign Tree[gl][gj] = Tree[gl-1][2*gj] + Tree[gl-1][2*gj+1];
                end else begin : G_PASS
                    assign Tree[gl][gj] = Tree[gl-1][2*gj];
                end
            end
        end
    endgenerate

    wire signed [Acc_W-1:0] Sum_Comb = Tree[LVLS][0];

    // ---- Output register ----
    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Valid_Out <= 1'b0;
            Acc_Out   <= {Acc_W{1'b0}};
        end else begin
            Valid_Out <= Valid_D1;
            Acc_Out   <= Sum_Comb;
        end
    end
endmodule

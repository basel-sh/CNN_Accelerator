//==============================================================================
// fifo_pair.v | NEW MODULE (2026-09-12) - fixed-point-count output queue
//
// Added because top_2px.v previously had no output buffering at all: it
// hard-wired Out_Full=1'b0 and a result computed while Out_Rd_En=0 was
// silently overwritten the next cycle, not held or queued (confirmed by
// simulation - see ERR-04 / TIM-06 in Verification_Test_Plan.xlsx).
//
// This is a synchronous, first-word-fall-through (show-ahead) FIFO storing
// DEPTH pairs (one entry = one cycle's Out_Data0/Out_Data1 from mac_pair.v).
// FWFT semantics: Rdata0/Rdata1/Valid are combinational reads of the head
// entry, so they do not change and stay valid until an actual read (Rd_En
// while not Empty) pops the head - matching what TIM-06 expects. Empty/Full
// are derived from a one-extra-bit Wptr/Rptr compare (the standard trick),
// matching the Wptr/Rptr language in RST-03/ERR-04's test descriptions.
//==============================================================================
module fifo_pair #(
    parameter DATA_W = 20,
    parameter DEPTH  = 16               // must be a power of 2
)(
    input  wire                    Clk,
    input  wire                    Rst_N,
    input  wire                    Wr_En,
    input  wire signed [DATA_W-1:0] Wdata0,
    input  wire signed [DATA_W-1:0] Wdata1,
    input  wire                    Rd_En,
    output wire signed [DATA_W-1:0] Rdata0,
    output wire signed [DATA_W-1:0] Rdata1,
    output wire                    Empty,
    output wire                    Full,
    output wire                    Valid
);
    localparam AW = $clog2(DEPTH);

    reg signed [DATA_W-1:0] Mem0 [0:DEPTH-1];
    reg signed [DATA_W-1:0] Mem1 [0:DEPTH-1];
    reg [AW:0] Wptr, Rptr;   // one extra bit distinguishes full from empty

    assign Empty  = (Wptr == Rptr);
    assign Full   = (Wptr[AW] != Rptr[AW]) && (Wptr[AW-1:0] == Rptr[AW-1:0]);
    assign Valid  = !Empty;
    assign Rdata0 = Mem0[Rptr[AW-1:0]];
    assign Rdata1 = Mem1[Rptr[AW-1:0]];

    wire Do_Wr = Wr_En && !Full;   // Wr_En && !Full guard: a write while full is dropped, not corrupting the queue
    wire Do_Rd = Rd_En && !Empty;  // Rd_En && !Empty guard: a read while empty does not advance/pop anything

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Wptr <= {(AW+1){1'b0}};
            Rptr <= {(AW+1){1'b0}};
        end else begin
            if (Do_Wr) begin
                Mem0[Wptr[AW-1:0]] <= Wdata0;
                Mem1[Wptr[AW-1:0]] <= Wdata1;
                Wptr <= Wptr + 1'b1;
            end
            if (Do_Rd) begin
                Rptr <= Rptr + 1'b1;
            end
        end
    end
endmodule

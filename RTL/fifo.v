//==============================================================================
// fifo.v | Module: fifo | Phase 3 - Memory Architecture
// Generic synchronous FIFO (independent write/read pointers, full/empty
// flags). Used by RTL/output_buffer.v to decouple MAC timing from output.
//==============================================================================
module fifo #(
    parameter Width = 20,
    parameter Depth = 64,
    parameter Aw    = 6      // ceil(log2(Depth))
)(
    input  wire              Clk,
    input  wire              Rst_N,
    input  wire              Wr_En,
    input  wire [Width-1:0]  Wr_Data,
    input  wire              Rd_En,
    output wire [Width-1:0]  Rd_Data,
    output wire              Full,
    output wire              Empty
);
    reg [Width-1:0] Mem [0:Depth-1];
    reg [Aw:0] Wptr, Rptr;   // one extra MSB disambiguates full vs empty

    assign Rd_Data = Mem[Rptr[Aw-1:0]];
    assign Empty   = (Wptr == Rptr);
    assign Full    = (Wptr[Aw-1:0] == Rptr[Aw-1:0]) && (Wptr[Aw] != Rptr[Aw]);

    always @(posedge Clk or negedge Rst_N) begin
        if (!Rst_N) begin
            Wptr <= {(Aw+1){1'b0}};
            Rptr <= {(Aw+1){1'b0}};
        end else begin
            if (Wr_En && !Full) begin
                Mem[Wptr[Aw-1:0]] <= Wr_Data;
                Wptr <= Wptr + 1'b1;
            end
            if (Rd_En && !Empty)
                Rptr <= Rptr + 1'b1;
        end
    end
endmodule

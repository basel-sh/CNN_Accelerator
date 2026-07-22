//==============================================================================
// File     : fifo.v   |  Module: fifo   |  Phase 3 - Memory Architecture
// Generic parameterizable synchronous FIFO (independent write/read pointers,
// full/empty flags). Used by RTL/output_buffer.v to decouple MAC production
// timing from result consumption timing.
//==============================================================================
module fifo #(
    parameter WIDTH = 20,
    parameter DEPTH = 64,
    parameter AW    = 6      // ceil(log2(DEPTH))
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              wr_en,
    input  wire [WIDTH-1:0]  wr_data,
    input  wire              rd_en,
    output wire [WIDTH-1:0]  rd_data,
    output wire              full,
    output wire              empty
);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW:0] wptr, rptr;   // one extra MSB to disambiguate full vs empty

    assign rd_data = mem[rptr[AW-1:0]];
    assign empty   = (wptr == rptr);
    assign full    = (wptr[AW-1:0] == rptr[AW-1:0]) && (wptr[AW] != rptr[AW]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= {(AW+1){1'b0}};
            rptr <= {(AW+1){1'b0}};
        end else begin
            if (wr_en && !full) begin
                mem[wptr[AW-1:0]] <= wr_data;
                wptr <= wptr + 1'b1;
            end
            if (rd_en && !empty)
                rptr <= rptr + 1'b1;
        end
    end
endmodule

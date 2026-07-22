//==============================================================================
// File   : output_buffer.v  |  Module: output_buffer  |  Phase 8
// Applies optional ReLU to each valid MAC result and pushes it into a fifo.v
// instance, decoupling MAC production timing from result consumption timing.
//==============================================================================
module output_buffer #(
    parameter ACC_W = 20,
    parameter DEPTH = 1024,
    parameter AW    = 10
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     relu_en,
    input  wire                     valid_in,
    input  wire signed [ACC_W-1:0]  data_in,
    input  wire                     rd_en,
    output wire signed [ACC_W-1:0]  data_out,
    output wire                     out_valid,   // !empty
    output wire                     full
);
    wire signed [ACC_W-1:0] relu_data = (relu_en && data_in[ACC_W-1]) ? {ACC_W{1'b0}} : data_in;
    wire empty;

    fifo #(
        .WIDTH(ACC_W),
        .DEPTH(DEPTH),
        .AW(AW)
    ) u_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (valid_in),
        .wr_data (relu_data),
        .rd_en   (rd_en),
        .rd_data (data_out),
        .full    (full),
        .empty   (empty)
    );

    assign out_valid = ~empty;
endmodule

//==============================================================================
// output_buffer.v | Module: output_buffer | Phase 8 - Top Integration
// Applies optional ReLU to each valid MAC result and pushes it into a fifo.v
// instance, decoupling MAC production timing from result consumption.
//==============================================================================
module output_buffer #(
    parameter Acc_W = 20,
    parameter Depth = 1024,
    parameter Aw    = 10
)(
    input  wire                     Clk,
    input  wire                     Rst_N,
    input  wire                     Relu_En,
    input  wire                     Valid_In,
    input  wire signed [Acc_W-1:0]  Data_In,
    input  wire                     Rd_En,
    output wire signed [Acc_W-1:0]  Data_Out,
    output wire                     Out_Valid,   // !Empty
    output wire                     Full
);
    wire signed [Acc_W-1:0] Relu_Data = (Relu_En && Data_In[Acc_W-1]) ? {Acc_W{1'b0}} : Data_In;
    wire Empty;

    fifo #(
        .Width(Acc_W),
        .Depth(Depth),
        .Aw(Aw)
    ) U_Fifo (
        .Clk      (Clk),
        .Rst_N    (Rst_N),
        .Wr_En    (Valid_In),
        .Wr_Data  (Relu_Data),
        .Rd_En    (Rd_En),
        .Rd_Data  (Data_Out),
        .Full     (Full),
        .Empty    (Empty)
    );

    assign Out_Valid = ~Empty;
endmodule

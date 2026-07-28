//==============================================================================
// File     : ram.v   |  Module: ram   |  Phase 3 - Memory Architecture
// Generic parameterizable synchronous single-port-style RAM (separate write
// and read address so it infers cleanly onto Xilinx Block RAM / distributed
// RAM). Read has 1-cycle latency (registered), matching BRAM behavior.
//
// NOTE: when waddr == raddr on the same we=1 cycle, rdata returns the OLD
// value (read-before-write), because both assignments below are nonblocking
// and evaluate against the pre-cycle memory contents. RTL/line_buffer.v
// deliberately relies on this to implement a fixed-depth row-delay line.
//==============================================================================
module ram #(
    parameter WIDTH = 8,
    parameter DEPTH = 1024,
    parameter ADDRW = 10
)(
    input  wire                  clk,
    input  wire                  WriteEnable,
    input  wire [ADDRW-1:0]      WriteAddr,
    input  wire [WIDTH-1:0]      WriteData,
    input  wire [ADDRW-1:0]      ReadAddr,
    output reg  [WIDTH-1:0]      ReadData
);
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (WriteEnable)
            mem[WriteAddr] <= WriteData;
        ReadData <= mem[ReadAddr];
    end
endmodule

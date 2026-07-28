//==============================================================================
// ram.v | Module: ram | Phase 3 - Memory Architecture
// Generic synchronous RAM (separate write/read address) that infers cleanly
// onto Xilinx Block RAM / distributed RAM. Read has 1-cycle latency.
//
// NOTE: on Write_Addr == Read_Addr with Write_Enable=1, Read_Data returns the
// OLD value (read-before-write) - RTL/line_buffer.v relies on this on purpose.
//==============================================================================
module ram #(
    parameter Width = 8,
    parameter Depth = 1024,
    parameter Addrw = 10
)(
    input  wire                 Clk,
    input  wire                 Write_Enable,
    input  wire [Addrw-1:0]     Write_Addr,
    input  wire [Width-1:0]     Write_Data,
    input  wire [Addrw-1:0]     Read_Addr,
    output reg  [Width-1:0]     Read_Data
);
    reg [Width-1:0] Mem [0:Depth-1];

    always @(posedge Clk) begin
        if (Write_Enable)
            Mem[Write_Addr] <= Write_Data;
        Read_Data <= Mem[Read_Addr];
    end
endmodule

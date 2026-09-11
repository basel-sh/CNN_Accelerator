//==============================================================================
// controller_2px.v | Controller for a true 2-pixel/cycle input stream
//
// Each clock reads two adjacent pixels: columns 0/1, 2/3, ... 30/31.
// After the two-pixel pipeline is primed, every pair whose first column is
// >=2 produces two adjacent output pixels. For 32x32/K=3 there are 16 input
// pairs per row and 15 valid output pairs per row = 30 outputs/row.
//==============================================================================
module controller_2px #(
    parameter Img_W = 32,
    parameter Img_H = 32,
    parameter K     = 3,
    parameter Addrw = 10
)(
    input  wire                 Clk,
    input  wire                 Rst_N,
    input  wire                 Start,
    output reg  [Addrw-1:0]     Mem_Raddr0,
    output reg  [Addrw-1:0]     Mem_Raddr1,
    output reg                  Streaming,
    output reg                  Pair_Valid,
    output reg                  Busy,
    output reg                  Scan_Done
);
    localparam Total_Pairs = (Img_W*Img_H)/2;
    reg [Addrw-1:0] Row, Col;
    reg [$clog2(Total_Pairs+1)-1:0] Cnt;
    localparam S_Idle = 2'd0, S_Run = 2'd1, S_Done = 2'd2;
    reg [1:0] State;

    always @(posedge Clk) begin
        if (!Rst_N) begin
            State      <= S_Idle;
            Row        <= 0;
            Col        <= 0;
            Cnt        <= 0;
            Mem_Raddr0 <= 0;
            Mem_Raddr1 <= 1;
            Streaming  <= 1'b0;
            Pair_Valid <= 1'b0;
            Busy       <= 1'b0;
            Scan_Done  <= 1'b0;
        end else begin
            Scan_Done <= 1'b0;
            case (State)
                S_Idle: begin
                    Streaming  <= 1'b0;
                    Pair_Valid <= 1'b0;
                    Busy       <= 1'b0;
                    if (Start) begin
                        Row   <= 0;
                        Col   <= 0;
                        Cnt   <= 0;
                        State <= S_Run;
                        Busy  <= 1'b1;
                    end
                end
                S_Run: begin
                    Mem_Raddr0 <= Row*Img_W + Col;
                    Mem_Raddr1 <= Row*Img_W + Col + 1'b1;
                    Streaming  <= 1'b1;
                    Pair_Valid <= (Row >= K-1) && (Col >= K-1);

                    if (Col == Img_W-2) begin
                        Col <= 0;
                        Row <= Row + 1'b1;
                    end else begin
                        Col <= Col + 2;
                    end

                    Cnt <= Cnt + 1'b1;
                    if (Cnt == Total_Pairs-1) begin
                        State     <= S_Done;
                        Scan_Done <= 1'b1;
                    end
                end
                S_Done: begin
                    Streaming  <= 1'b0;
                    Pair_Valid <= 1'b0;
                    Busy       <= 1'b0;
                    State      <= S_Idle;
                end
                default: State <= S_Idle;
            endcase
        end
    end
endmodule

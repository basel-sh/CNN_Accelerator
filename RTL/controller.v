//==============================================================================
// controller.v | Module: controller | Phase 7 - Controller FSM
// Sequences the raster-scan read of image_memory (row-major, one pixel per
// cycle) and computes the "raw" valid-window tag (asserted once the scan has
// passed the first K-1 rows/cols). Fine-grained pipeline-latency alignment
// is handled in top.v, which knows the datapath's exact structural latency.
//==============================================================================
module controller #(
    parameter Img_W = 32,
    parameter Img_H = 32,
    parameter K     = 3,
    parameter Addrw = 10
)(
    input  wire                Clk,
    input  wire                Rst_N,
    input  wire                Start,
    output reg  [Addrw-1:0]    Mem_Raddr,
    output reg                 Streaming,   // 1 while a new address is issued this cycle
    output reg                 Raw_Valid,   // 1 if this address lies within a full KxK window
    output reg                 Busy,
    output reg                 Scan_Done    // 1 for one cycle when the last address has issued
);
    localparam Total = Img_W * Img_H;

    reg [Addrw-1:0] Row, Col;
    reg [$clog2(Total+1)-1:0] Cnt;

    localparam S_Idle = 2'd0, S_Run = 2'd1, S_Done = 2'd2;
    reg [1:0] State;

    always @(posedge Clk) begin  // synchronous reset - Mem_Raddr/Streaming feed BlockRAM control pins (REQP-1840 fix)
        if (!Rst_N) begin
            State     <= S_Idle;
            Row       <= {Addrw{1'b0}};
            Col       <= {Addrw{1'b0}};
            Cnt       <= 0;
            Mem_Raddr <= {Addrw{1'b0}};
            Streaming <= 1'b0;
            Raw_Valid <= 1'b0;
            Busy      <= 1'b0;
            Scan_Done <= 1'b0;
        end else begin
            Scan_Done <= 1'b0;
            case (State)
                S_Idle: begin
                    Streaming <= 1'b0;
                    Busy      <= 1'b0;
                    if (Start) begin
                        Row   <= 0;
                        Col   <= 0;
                        Cnt   <= 0;
                        State <= S_Run;
                        Busy  <= 1'b1;
                    end
                end

                S_Run: begin
                    Mem_Raddr <= Row * Img_W + Col;
                    Raw_Valid <= (Row >= K-1) && (Col >= K-1);
                    Streaming <= 1'b1;

                    if (Col == Img_W-1) begin
                        Col <= 0;
                        Row <= Row + 1'b1;
                    end else begin
                        Col <= Col + 1'b1;
                    end

                    Cnt <= Cnt + 1'b1;
                    if (Cnt == Total-1) begin
                        State     <= S_Done;
                        Scan_Done <= 1'b1;
                    end
                end

                S_Done: begin
                    Streaming <= 1'b0;
                    Raw_Valid <= 1'b0;
                    Busy      <= 1'b0;
                    State     <= S_Idle;
                end

                default: State <= S_Idle;
            endcase
        end
    end
endmodule

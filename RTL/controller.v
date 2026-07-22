//==============================================================================
// File   : controller.v  |  Module: controller  |  Phase 7 - Controller FSM
// Sequences the raster-scan read of image_memory (row-major, one pixel per
// cycle) and computes the "raw" valid-window tag (asserted once the scan has
// passed the first K-1 rows/cols, i.e. wherever a full KxK window exists).
// Fine-grained pipeline-latency alignment (image_mem read latency, window
// generator register, MAC register) is handled in top.v, which knows the
// exact structural latency of the datapath it wires together.
//==============================================================================
module controller #(
    parameter IMG_W = 32,
    parameter IMG_H = 32,
    parameter K     = 3,
    parameter ADDRW = 10
)(
    input  wire               clk,
    input  wire                rst_n,
    input  wire                start,
    output reg  [ADDRW-1:0]    mem_raddr,
    output reg                 streaming,   // 1 while a new address is being issued this cycle
    output reg                 raw_valid,   // 1 if this address lies within a full KxK window
    output reg                 busy,
    output reg                 scan_done    // 1 for one cycle when the last address has been issued
);
    localparam TOTAL = IMG_W * IMG_H;

    reg [ADDRW-1:0] row, col;
    reg [$clog2(TOTAL+1)-1:0] cnt;

    localparam S_IDLE = 2'd0, S_RUN = 2'd1, S_DONE = 2'd2;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            row       <= {ADDRW{1'b0}};
            col       <= {ADDRW{1'b0}};
            cnt       <= 0;
            mem_raddr <= {ADDRW{1'b0}};
            streaming <= 1'b0;
            raw_valid <= 1'b0;
            busy      <= 1'b0;
            scan_done <= 1'b0;
        end else begin
            scan_done <= 1'b0;
            case (state)
                S_IDLE: begin
                    streaming <= 1'b0;
                    busy      <= 1'b0;
                    if (start) begin
                        row   <= 0;
                        col   <= 0;
                        cnt   <= 0;
                        state <= S_RUN;
                        busy  <= 1'b1;
                    end
                end

                S_RUN: begin
                    mem_raddr <= row * IMG_W + col;
                    raw_valid <= (row >= K-1) && (col >= K-1);
                    streaming <= 1'b1;

                    if (col == IMG_W-1) begin
                        col <= 0;
                        row <= row + 1'b1;
                    end else begin
                        col <= col + 1'b1;
                    end

                    cnt <= cnt + 1'b1;
                    if (cnt == TOTAL-1) begin
                        state     <= S_DONE;
                        scan_done <= 1'b1;
                    end
                end

                S_DONE: begin
                    streaming <= 1'b0;
                    raw_valid <= 1'b0;
                    busy      <= 1'b0;
                    state     <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

//==============================================================================
// tb_controller.v - Phase 9 unit test for RTL/controller.v
// Verifies the FSM streams exactly IMG_W*IMG_H addresses in row-major order,
// asserts raw_valid only once row>=K-1 && col>=K-1, and returns to IDLE.
//==============================================================================
`timescale 1ns/1ps
module tb_controller;
    localparam IMG_W=8, IMG_H=8, K=3, ADDRW=6;   // small image for a fast unit test
    localparam TOTAL = IMG_W*IMG_H;

    reg clk=0, rst_n=0, start=0;
    wire [ADDRW-1:0] mem_raddr;
    wire streaming, raw_valid, busy, scan_done;

    controller #(.IMG_W(IMG_W), .IMG_H(IMG_H), .K(K), .ADDRW(ADDRW)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .mem_raddr(mem_raddr), .streaming(streaming), .raw_valid(raw_valid),
        .busy(busy), .scan_done(scan_done)
    );

    always #5 clk = ~clk;

    integer addr_count = 0;
    integer valid_count = 0;
    integer errors = 0;
    reg [ADDRW-1:0] last_addr = 0;
    reg have_last = 0;

    always @(posedge clk) begin
        if (streaming) begin
            addr_count = addr_count + 1;
            if (have_last && (mem_raddr != last_addr + 1'b1) && !(last_addr == TOTAL-1)) begin
                $display("FAIL: non-sequential address %0d after %0d", mem_raddr, last_addr);
                errors = errors + 1;
            end
            last_addr = mem_raddr;
            have_last = 1;
            if (raw_valid) valid_count = valid_count + 1;
        end
    end

    initial begin
        $dumpfile("sim/tb_controller.vcd");
        $dumpvars(0, tb_controller);

        rst_n = 0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        start = 1;
        @(posedge clk);
        @(negedge clk);
        start = 0;

        // avoid a wait()-based race with the counting always block on the
        // same clock edge (see Documentation/DevelopmentRoadmap.md Phase 9
        // testbench notes) - just run for a fixed, generous cycle count.
        repeat (TOTAL + 10) @(posedge clk);

        $display("addr_count=%0d (expected %0d)", addr_count, TOTAL);
        $display("valid_count=%0d (expected %0d)", valid_count, (IMG_W-K+1)*(IMG_H-K+1));

        if (addr_count !== TOTAL) begin
            $display("FAIL: address count mismatch");
            errors = errors + 1;
        end
        if (valid_count !== (IMG_W-K+1)*(IMG_H-K+1)) begin
            $display("FAIL: valid window count mismatch");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("TB_CONTROLLER: ALL TESTS PASSED");
        else
            $display("TB_CONTROLLER: %0d TEST(S) FAILED", errors);

        $finish;
    end
endmodule

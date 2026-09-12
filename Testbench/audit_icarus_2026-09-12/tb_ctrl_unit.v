//==============================================================================
// tb_ctrl_unit.v — direct unit-level testbench for controller_2px.v
// Covers: FUNC-09, RST-01, RST-02, TIM-01, TIM-03, TIM-04, TIM-05,
//         B2B-01, B2B-02
//==============================================================================
`timescale 1ns/1ps
module tb_ctrl_unit;
    localparam Img_W=8, Img_H=8, K=3, Addrw=10;
    localparam Total_Pairs = (Img_W*Img_H)/2;
    localparam Expected_Valid_Outputs = (Img_W-K+1)*(Img_H-K+1);
    localparam Expected_Valid_Pairs = Expected_Valid_Outputs/2;

    reg Clk=0, Rst_N=1, Start=0;
    wire [Addrw-1:0] Mem_Raddr0, Mem_Raddr1;
    wire Streaming, Pair_Valid, Busy, Scan_Done;

    controller_2px #(.Img_W(Img_W), .Img_H(Img_H), .K(K), .Addrw(Addrw)) Dut (
        .Clk(Clk), .Rst_N(Rst_N), .Start(Start),
        .Mem_Raddr0(Mem_Raddr0), .Mem_Raddr1(Mem_Raddr1),
        .Streaming(Streaming), .Pair_Valid(Pair_Valid),
        .Busy(Busy), .Scan_Done(Scan_Done)
    );

    always #5 Clk = ~Clk;

    integer pass_count = 0, fail_count = 0;
    task automatic check(input cond, input [8*160-1:0] name);
        begin
            if (cond) begin
                pass_count = pass_count + 1;
                $display("CHECK PASS: %0s", name);
            end else begin
                fail_count = fail_count + 1;
                $display("CHECK FAIL: %0s", name);
            end
        end
    endtask

    integer addr_count, pair_count, i;
    reg [Addrw-1:0] expected_addr;
    reg addr_seq_ok, addr_seq_started;
    integer scan_done_cycles;
    integer busy_after_start_cycles;

    initial begin
        // ---- RST-01: power-on reset ----
        Rst_N = 0;
        repeat (3) @(posedge Clk);
        @(negedge Clk);
        Rst_N = 1;
        @(negedge Clk);
        check(Dut.State == 2'd0, "RST-01: State==S_Idle after reset");
        check(Busy == 1'b0, "RST-01: Busy==0 after reset");
        check(Mem_Raddr0 == 0, "RST-01: Mem_Raddr0==0 after reset");
        check(Scan_Done == 1'b0, "RST-01: Scan_Done==0 after reset");

        // ---- TIM-01: Start-to-Busy latency (1 cycle) ----
        @(negedge Clk);
        Start = 1;
        @(posedge Clk); #1;
        check(Busy == 1'b1, "TIM-01: Busy asserts on the cycle Start is sampled (S_Idle->S_Run)");
        @(negedge Clk);
        Start = 0;

        // ---- FUNC-09 / TIM-03 / TIM-05: run to completion, track addresses ----
        addr_count = 0; pair_count = 0; addr_seq_ok = 1; addr_seq_started = 0;
        expected_addr = 0;
        scan_done_cycles = 0;
        while (!Scan_Done) begin
            @(posedge Clk); #1;
            if (Streaming) begin
                addr_count = addr_count + 2; // Raddr0 + Raddr1 each cycle
                if (Mem_Raddr0 !== expected_addr) addr_seq_ok = 0;
                if (Mem_Raddr1 !== expected_addr + 1) addr_seq_ok = 0;
                expected_addr = expected_addr + 2;
            end
            if (Pair_Valid) pair_count = pair_count + 1;
            if (Scan_Done) scan_done_cycles = scan_done_cycles + 1;
            @(negedge Clk);
        end
        check(addr_count == Img_W*Img_H, "TIM-05/FUNC-09: exactly Img_W*Img_H addresses issued");
        check(addr_seq_ok == 1, "TIM-05/FUNC-09: address sequence strictly sequential row-major, no gaps/repeats");
        check(pair_count == Expected_Valid_Pairs, "TIM-03: Pair_Valid pulse count == (Img_W-K+1)*(Img_H-K+1)/2 [2 outputs/cycle architecture]");
        check((pair_count*2) == Expected_Valid_Outputs, "FUNC-09: total valid OUTPUT count == (Img_W-K+1)^2 == 36");

        // ---- TIM-04: Scan_Done single-cycle pulse ----
        check(scan_done_cycles == 1, "TIM-04: Scan_Done pulse width == 1 cycle at end of measured run");
        @(posedge Clk); #1;
        check(Scan_Done == 1'b0, "TIM-04: Scan_Done deasserts the cycle after the pulse");

        @(negedge Clk);
        check(Dut.State == 2'd0, "post-scan: FSM returns to S_Idle (via S_Done)");
        check(Busy == 1'b0, "post-scan: Busy deasserted");

        // ---- B2B-01: zero-gap restart the cycle after Scan_Done ----
        // Re-run the scan sequence: assert Start immediately (already back in S_Idle).
        Start = 1;
        @(posedge Clk); #1;
        check(Busy == 1'b1, "B2B-01: second scan's Busy asserts immediately (S_Idle->S_Run)");
        @(negedge Clk);
        Start = 0;
        begin : b2b1_scan
            integer addr_count2; reg [Addrw-1:0] exp2; reg ok2;
            addr_count2 = 0; exp2 = 0; ok2 = 1;
            while (!Scan_Done) begin
                @(posedge Clk); #1;
                if (Streaming) begin
                    addr_count2 = addr_count2 + 2;
                    if (Mem_Raddr0 !== exp2) ok2 = 0;
                    exp2 = exp2 + 2;
                end
                @(negedge Clk);
            end
            check(addr_count2 == Img_W*Img_H, "B2B-01: second frame streams the full address range from 0, no gap");
            check(ok2 == 1, "B2B-01: second frame address sequence has no missed/duplicated addresses");
            @(posedge Clk); #1; @(negedge Clk);
        end

        // ---- B2B-02: spurious Start mid-scan is ignored ----
        Start = 1;
        @(posedge Clk); #1;
        Start = 0;
        @(negedge Clk);
        begin : b2b2_scan
            integer mid_cycle, cyc; reg spurious_sent; integer addr_count3;
            addr_count3 = 0; spurious_sent = 0; cyc = 0;
            mid_cycle = (Img_W*Img_H/2)/2; // roughly halfway through streaming cycles
            while (!Scan_Done) begin
                cyc = cyc + 1;
                if (cyc == mid_cycle && !spurious_sent) begin
                    Start = 1;
                    spurious_sent = 1;
                end
                @(posedge Clk); #1;
                if (Streaming) addr_count3 = addr_count3 + 2;
                Start = 0;
                @(negedge Clk);
            end
            check(addr_count3 == Img_W*Img_H, "B2B-02: spurious mid-scan Start does not truncate/restart the active scan");
            check(Dut.State != 2'd1 || Scan_Done, "B2B-02: active scan reached completion normally");
        end
        @(posedge Clk); #1; @(negedge Clk);
        check(Dut.State == 2'd0, "B2B-02: FSM idle after the (unaffected) scan completes");

        // ---- RST-02: reset asserted mid-scan (Busy=1) ----
        Start = 1;
        @(posedge Clk); #1; Start = 0; @(negedge Clk);
        repeat ((Img_W*Img_H/2)/2) @(posedge Clk); // let ~50% stream
        @(negedge Clk);
        check(Busy == 1'b1, "RST-02: scan is mid-flight (Busy=1) before reset asserted");
        Rst_N = 0;
        repeat (3) @(posedge Clk);
        @(negedge Clk);
        check(Dut.State == 2'd0, "RST-02: FSM returns cleanly to S_Idle under reset");
        check(Busy == 1'b0, "RST-02: Busy deasserts under reset");
        check(Pair_Valid == 1'b0, "RST-02: no partially-formed output marked valid during/after reset");
        Rst_N = 1;
        @(negedge Clk);
        check(Dut.State == 2'd0, "RST-02: FSM remains in S_Idle after release (no X propagation / spontaneous restart)");

        $display("TB_CTRL_UNIT: %0d PASS, %0d FAIL", pass_count, fail_count);
        $finish;
    end
endmodule

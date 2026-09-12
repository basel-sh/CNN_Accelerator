//==============================================================================
// tb_backpressure.v — ERR-03, ERR-04, TIM-06, RST-03, ERR-05
// Exercises Out_Rd_En=0 (no consumer), Out_Full monitoring, reset with
// "queued" results, and writes asserted mid-scan.
//==============================================================================
`timescale 1ns/1ps
module tb_backpressure;
    localparam Pixel_W=8, Kernel_W=8, Acc_W=20, Img_W=8, Img_H=8, K=3, Addrw=6, Kidxw=4;
    localparam Total_Pix=Img_W*Img_H, Num_K=K*K;
    localparam Expected_Outputs=(Img_W-K+1)*(Img_H-K+1);

    reg Clk=0, Rst_N=0, Start=0, Relu_En=0;
    reg Img_We=0; reg [Addrw-1:0] Img_Waddr=0; reg [Pixel_W-1:0] Img_Wdata=0;
    reg Kernel_We=0; reg [Kidxw-1:0] Kernel_Windex=0; reg signed [Kernel_W-1:0] Kernel_Wdata=0;
    reg Out_Rd_En=1;
    wire signed [Acc_W-1:0] Out_Data0, Out_Data1;
    wire Out_Valid, Out_Full, Busy, Scan_Done;

    top_2px #(.Pixel_W(Pixel_W),.Kernel_W(Kernel_W),.Acc_W(Acc_W),.Img_W(Img_W),.Img_H(Img_H),
              .K(K),.Img_Addrw(Addrw),.Kidxw(Kidxw)) Dut (
        .Clk(Clk),.Rst_N(Rst_N),.Start(Start),.Relu_En(Relu_En),.Busy(Busy),.Scan_Done(Scan_Done),
        .Img_We(Img_We),.Img_Waddr(Img_Waddr),.Img_Wdata(Img_Wdata),
        .Kernel_We(Kernel_We),.Kernel_Windex(Kernel_Windex),.Kernel_Wdata(Kernel_Wdata),
        .Out_Rd_En(Out_Rd_En),.Out_Data0(Out_Data0),.Out_Data1(Out_Data1),
        .Out_Valid(Out_Valid),.Out_Full(Out_Full)
    );
    always #5 Clk = ~Clk;

    integer pass_count=0, fail_count=0;
    task automatic check(input cond, input [8*160-1:0] name);
        begin
            if (cond) begin pass_count=pass_count+1; $display("CHECK PASS: %0s", name); end
            else begin fail_count=fail_count+1; $display("CHECK FAIL: %0s", name); end
        end
    endtask

    reg [Pixel_W-1:0] Image_Stim [0:Total_Pix-1];
    reg signed [Kernel_W-1:0] Kernel_K [0:Num_K-1];
    integer I;
    integer full_seen, dropped_valid_cycles;
    integer out_full_monitor_active;
    reg signed [Acc_W-1:0] sample_a, sample_b;

    initial begin
        $readmemh("mem/bp_image.mem", Image_Stim);
        $readmemh("mem/bp_kernel.mem", Kernel_K);

        // ---- ERR-03: read attempted while nothing has ever been valid ----
        Rst_N=0; repeat(3) @(posedge Clk); @(negedge Clk); Rst_N=1;
        Out_Rd_En = 1;
        repeat (5) begin
            @(posedge Clk); #1;
            check(Out_Valid == 1'b0, "ERR-03: Out_Valid stays 0 when Out_Rd_En=1 but no result exists yet (no lockup)");
            @(negedge Clk);
        end

        // Load stimulus for the backpressure run.
        for (I=0;I<Total_Pix;I=I+1) begin
            Img_We=1; Img_Waddr=I[Addrw-1:0]; Img_Wdata=Image_Stim[I];
            @(posedge Clk); @(negedge Clk);
        end
        Img_We=0;
        for (I=0;I<Num_K;I=I+1) begin
            Kernel_We=1; Kernel_Windex=I[Kidxw-1:0]; Kernel_Wdata=Kernel_K[I];
            @(posedge Clk); @(negedge Clk);
        end
        Kernel_We=0;

        // ---- ERR-04 / TIM-06: run with consumer NOT draining (Out_Rd_En=0) ----
        // POST-FIX 2026-09-12: a 16-deep fifo_pair.v now sits between mac_pair.v
        // and the output ports. FWFT semantics mean Out_Valid=1 as soon as the
        // queue holds >=1 entry (independent of Out_Rd_En), and the head entry
        // (Out_Data0/Out_Data1) is held constant until an actual read pops it.
        // Once the queue fills (16 entries) Out_Full asserts and further writes
        // are dropped (Do_Wr = Wr_En && !Full) instead of corrupting the queue.
        Out_Rd_En = 0;
        full_seen = 0; dropped_valid_cycles = 0;
        Start=1; @(posedge Clk); @(negedge Clk); Start=0;
        while (!Scan_Done) begin
            @(posedge Clk); #1;
            if (Out_Full) full_seen = full_seen + 1;
            if (Dut.Mac_Valid_Out) begin
                dropped_valid_cycles = dropped_valid_cycles + 1;
                // sample once Out_Valid is genuinely up (1st pulse's write is
                // still landing in the FIFO this same cycle, so it reads back
                // as X here - wait one more pulse before taking sample_a)
                if (dropped_valid_cycles == 2) sample_a = Out_Data0;
                if (dropped_valid_cycles == 9) begin // still well inside the 16-deep queue
                    sample_b = Out_Data0;
                    check(sample_a === sample_b, "TIM-06: Out_Data0 held for a later read (FIFO head unchanged, fixed)");
                end
            end
            @(negedge Clk);
        end
        // Drain margin: the MAC pipeline still has results in flight when
        // Scan_Done first asserts (same reasoning as the other multi-phase
        // testbenches) - without this the queue never actually reaches Full.
        repeat (30) begin
            @(posedge Clk); #1;
            if (Out_Full) full_seen = full_seen + 1;
            if (Dut.Mac_Valid_Out) dropped_valid_cycles = dropped_valid_cycles + 1;
            @(negedge Clk);
        end
        check(Out_Valid == 1'b1, "TIM-06: Out_Valid asserted (queue non-empty) though Out_Rd_En stayed 0 whole scan");
        check(full_seen > 0, "ERR-04: Out_Full DOES assert once the 16-deep FIFO fills (fixed via fifo_pair.v)");
        check(dropped_valid_cycles > 16, "ERR-04: 18 results > 16-deep FIFO, so backpressure/queueing genuinely exercised");
        @(posedge Clk); @(negedge Clk);

        // ---- RST-03: reset with "unread results" still queued in the FIFO ----
        Rst_N = 0;
        repeat(3) @(posedge Clk);
        @(negedge Clk);
        check(Out_Valid == 1'b0, "RST-03: Out_Valid deasserted during/after reset");
        Rst_N = 1;
        @(negedge Clk);
        check(Out_Valid == 1'b0, "RST-03: queued FIFO entries cleared by reset (Wptr/Rptr->0), no stale valid");

        // Run a clean frame afterward with Out_Rd_En=1 to prove no residual corruption.
        begin : clean_run
            integer Out_File2, cap2;
            Out_Rd_En = 1;
            for (I=0;I<Total_Pix;I=I+1) begin
                Img_We=1; Img_Waddr=I[Addrw-1:0]; Img_Wdata=Image_Stim[I];
                @(posedge Clk); @(negedge Clk);
            end
            Img_We=0;
            for (I=0;I<Num_K;I=I+1) begin
                Kernel_We=1; Kernel_Windex=I[Kidxw-1:0]; Kernel_Wdata=Kernel_K[I];
                @(posedge Clk); @(negedge Clk);
            end
            Kernel_We=0;
            Out_File2=$fopen("sim/bp_clean_run.mem","w"); cap2=0;
            Start=1; @(posedge Clk); @(negedge Clk); Start=0;
            while (!Scan_Done) begin
                @(posedge Clk); #1;
                if (Rst_N && Out_Valid && Out_Rd_En) begin
                    $fwrite(Out_File2, "%05x\n", Out_Data0 & {Acc_W{1'b1}});
                    $fwrite(Out_File2, "%05x\n", Out_Data1 & {Acc_W{1'b1}});
                    cap2 = cap2 + 2;
                end
                @(negedge Clk);
            end
            repeat (30) begin
                @(posedge Clk); #1;
                if (Rst_N && Out_Valid && Out_Rd_En) begin
                    $fwrite(Out_File2, "%05x\n", Out_Data0 & {Acc_W{1'b1}});
                    $fwrite(Out_File2, "%05x\n", Out_Data1 & {Acc_W{1'b1}});
                    cap2 = cap2 + 2;
                end
                @(negedge Clk);
            end
            $fclose(Out_File2);
            check(cap2 == Expected_Outputs, "RST-03: post-reset clean run produces the full expected output count");
            $display("RST03_CLEAN_RUN: captured %0d (expected %0d)", cap2, Expected_Outputs);
        end

        // ---- ERR-05: Img_We / Kernel_We asserted while Busy=1 ----
        begin : err05
            integer x_seen;
            x_seen = 0;
            Start=1; @(posedge Clk); @(negedge Clk); Start=0;
            repeat (8) @(posedge Clk); // let the scan get going
            @(negedge Clk);
            check(Busy == 1'b1, "ERR-05: scan is active (Busy=1) before the mid-scan write");
            Img_We = 1; Img_Waddr = 3; Img_Wdata = 8'hCC;
            Kernel_We = 1; Kernel_Windex = 2; Kernel_Wdata = 8'sd5;
            @(posedge Clk); @(negedge Clk);
            Img_We = 0; Kernel_We = 0;
            while (!Scan_Done) begin
                @(posedge Clk); #1;
                if (Out_Valid && (Out_Data0 === {Acc_W{1'bx}})) x_seen = x_seen + 1;
                @(negedge Clk);
            end
            check(x_seen == 0, "ERR-05: no X propagation into Out_Data after a mid-scan Img_We/Kernel_We write");
            @(posedge Clk); @(negedge Clk);
            check(Busy == 1'b0, "ERR-05: scan still completes normally (no hang) despite the write during Busy=1 - RTL has no interlock, as documented");
        end

        $display("TB_BACKPRESSURE: %0d PASS, %0d FAIL", pass_count, fail_count);
        $finish;
    end
endmodule

//==============================================================================
// tb_top.v - Phase 9 system-level testbench for RTL/top.v
//
// 1. Preloads image_memory from Images/input_32x32.mem ($readmemh, unsigned)
// 2. Preloads kernel_memory from Images/kernels/edge_3x3.mem ($readmemh, signed
//    two's-complement hex)
// 3. Asserts start, streams the whole 32x32 image through the pipeline
// 4. Captures every valid output word (out_valid && out_rd_en) in the order
//    produced, and writes them (two's-complement hex) to sim/rtl_output.mem
// 5. Python/verify.py then compares sim/rtl_output.mem against the golden
//    model's Images/expected_output.mem for the automatic PASS/FAIL.
//==============================================================================
`timescale 1ns/1ps
module tb_top;
    localparam PIXEL_W=8, KERNEL_W=8, ACC_W=20, IMG_W=32, IMG_H=32, K=3;
    localparam IMG_ADDRW=10, KIDXW=4, OUT_DEPTH=1024, OUT_AW=10;
    localparam TOTAL_PIX = IMG_W*IMG_H;
    localparam NUM_K = K*K;
    localparam EXPECTED_OUTPUTS = (IMG_W-K+1)*(IMG_H-K+1);

    reg clk = 0, rst_n = 0;
    reg start = 0, relu_en = 0;
    reg img_we = 0;
    reg [IMG_ADDRW-1:0] img_waddr = 0;
    reg [PIXEL_W-1:0] img_wdata = 0;
    reg kernel_we = 0;
    reg [KIDXW-1:0] kernel_windex = 0;
    reg signed [KERNEL_W-1:0] kernel_wdata = 0;
    reg out_rd_en = 1;   // greedily consume every produced result
    wire signed [ACC_W-1:0] out_data;
    wire out_valid, out_full, busy, scan_done;

    top #(
        .PIXEL_W(PIXEL_W), .KERNEL_W(KERNEL_W), .ACC_W(ACC_W),
        .IMG_W(IMG_W), .IMG_H(IMG_H), .K(K),
        .IMG_ADDRW(IMG_ADDRW), .KIDXW(KIDXW),
        .OUT_DEPTH(OUT_DEPTH), .OUT_AW(OUT_AW)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .relu_en(relu_en),
        .busy(busy), .scan_done(scan_done),
        .img_we(img_we), .img_waddr(img_waddr), .img_wdata(img_wdata),
        .kernel_we(kernel_we), .kernel_windex(kernel_windex), .kernel_wdata(kernel_wdata),
        .out_rd_en(out_rd_en), .out_data(out_data), .out_valid(out_valid), .out_full(out_full)
    );

    always #5 clk = ~clk;

    reg [PIXEL_W-1:0] image_stim [0:TOTAL_PIX-1];
    reg signed [KERNEL_W-1:0] kernel_stim [0:NUM_K-1];

    integer i;
    integer out_file;
    integer capture_count;

    initial begin
        $dumpfile("sim/tb_top.vcd");
        $dumpvars(0, tb_top);

        $readmemh("Images/input_32x32.mem", image_stim);
        $readmemh("Images/kernels/edge_3x3.mem", kernel_stim);

        out_file = $fopen("sim/rtl_output.mem", "w");
        capture_count = 0;

        rst_n = 0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        // NOTE: all stimulus changes below happen on @(negedge clk), well away
        // from the DUT's own @(posedge clk) logic, to avoid a classic
        // same-edge testbench/DUT race on blocking-assigned stimulus signals
        // (see Documentation/DevelopmentRoadmap.md Phase 9 notes).

        // --- preload image memory ---
        for (i = 0; i < TOTAL_PIX; i = i + 1) begin
            img_we    = 1;
            img_waddr = i[IMG_ADDRW-1:0];
            img_wdata = image_stim[i];
            @(posedge clk);
            @(negedge clk);
        end
        img_we = 0;

        // --- preload kernel memory ---
        for (i = 0; i < NUM_K; i = i + 1) begin
            kernel_we    = 1;
            kernel_windex = i[KIDXW-1:0];
            kernel_wdata  = kernel_stim[i];
            @(posedge clk);
            @(negedge clk);
        end
        kernel_we = 0;

        // --- run convolution ---
        start = 1;
        @(posedge clk);
        @(negedge clk);
        start = 0;

        // Run long enough for TOTAL_PIX streaming cycles + pipeline drain + margin
        repeat (TOTAL_PIX + 50) @(posedge clk);

        $display("TB_TOP: captured %0d outputs (expected %0d)", capture_count, EXPECTED_OUTPUTS);
        if (capture_count == EXPECTED_OUTPUTS)
            $display("TB_TOP: OUTPUT COUNT MATCHES EXPECTATION");
        else
            $display("TB_TOP: *** OUTPUT COUNT MISMATCH ***");

        $fclose(out_file);
        $finish;
    end

    // capture every produced (and consumed) result, in FIFO order
    always @(posedge clk) begin
        if (rst_n && out_valid && out_rd_en) begin
            $fwrite(out_file, "%05x\n", out_data & {ACC_W{1'b1}});
            capture_count = capture_count + 1;
        end
    end
endmodule

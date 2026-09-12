//==============================================================================
// tb_axi_lite.v — TIM-08, TIM-09, ERR-06, ERR-07
// Drives real AXI4-Lite write/read handshakes against axi_lite_top_2px.v
// (a brand-new module written 2026-09-12 - no AXI RTL existed before this
// fix, so TIM-08/TIM-09/ERR-06/ERR-07 were previously Blocked).
//==============================================================================
`timescale 1ns/1ps
module tb_axi_lite;
    localparam Pixel_W=8, Kernel_W=8, Acc_W=20, Img_W=8, Img_H=8, K=3, Addrw=6, Kidxw=4;
    localparam Total_Pix=Img_W*Img_H, Num_K=K*K;

    reg Clk=0, Rst_N=0;
    reg [4:0] s_axi_awaddr=0; reg s_axi_awvalid=0; wire s_axi_awready;
    reg [31:0] s_axi_wdata=0; reg [3:0] s_axi_wstrb=4'hF; reg s_axi_wvalid=0; wire s_axi_wready;
    wire [1:0] s_axi_bresp; wire s_axi_bvalid; reg s_axi_bready=0;
    reg [4:0] s_axi_araddr=0; reg s_axi_arvalid=0; wire s_axi_arready;
    wire [31:0] s_axi_rdata; wire [1:0] s_axi_rresp; wire s_axi_rvalid; reg s_axi_rready=0;

    axi_lite_top_2px #(.Pixel_W(Pixel_W),.Kernel_W(Kernel_W),.Acc_W(Acc_W),
        .Img_W(Img_W), .Img_H(Img_H), .K(K), .Img_Addrw(Addrw), .Kidxw(Kidxw)) Dut (
        .Clk(Clk), .Rst_N(Rst_N),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready)
    );
    always #5 Clk = ~Clk;

    integer pass_count=0, fail_count=0;
    task automatic check(input cond, input [8*160-1:0] name);
        begin
            if (cond) begin pass_count=pass_count+1; $display("CHECK PASS: %0s", name); end
            else begin fail_count=fail_count+1; $display("CHECK FAIL: %0s", name); end
        end
    endtask

    // ---- AXI4-Lite bus-functional tasks ----
    integer wr_timeout;
    task automatic axi_write(input [4:0] addr, input [31:0] data);
        begin
            @(negedge Clk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = data;
            s_axi_wvalid  = 1'b1;
            wr_timeout = 0;
            while (!(s_axi_awready && s_axi_wready) && wr_timeout < 20) begin
                @(negedge Clk); wr_timeout = wr_timeout + 1;
            end
            @(negedge Clk);
            s_axi_awvalid = 1'b0;
            s_axi_wvalid  = 1'b0;
            s_axi_bready  = 1'b1;
            wr_timeout = 0;
            while (!s_axi_bvalid && wr_timeout < 20) begin
                @(negedge Clk); wr_timeout = wr_timeout + 1;
            end
            @(negedge Clk);
            s_axi_bready = 1'b0;
        end
    endtask

    reg [31:0] rd_capture;
    reg [1:0]  rresp_capture;
    task automatic axi_read(input [4:0] addr);
        begin
            @(negedge Clk);
            s_axi_araddr  = addr;
            s_axi_arvalid = 1'b1;
            wr_timeout = 0;
            while (!s_axi_arready && wr_timeout < 20) begin
                @(negedge Clk); wr_timeout = wr_timeout + 1;
            end
            @(negedge Clk);
            s_axi_arvalid = 1'b0;
            s_axi_rready  = 1'b1;
            wr_timeout = 0;
            while (!s_axi_rvalid && wr_timeout < 20) begin
                @(negedge Clk); wr_timeout = wr_timeout + 1;
            end
            rd_capture    = s_axi_rdata;
            rresp_capture = s_axi_rresp;
            @(negedge Clk);
            s_axi_rready = 1'b0;
        end
    endtask

    reg [Pixel_W-1:0] Image_Stim [0:Total_Pix-1];
    reg signed [Kernel_W-1:0] Kernel_K [0:Num_K-1];
    integer I;
    integer kwe_pulses, we_pulse_cycles;
    reg signed [Acc_W-1:0] expected_out0;

    initial begin
        // reuse the same backpressure stimulus files (8x8 image, 3x3 kernel)
        $readmemh("mem/bp_image.mem", Image_Stim);
        $readmemh("mem/bp_kernel.mem", Kernel_K);

        Rst_N=0; repeat(3) @(posedge Clk); @(negedge Clk); Rst_N=1;
        @(negedge Clk);

        // ---- TIM-08: KERNEL_WDATA (0x14) write pulses Kernel_We for exactly 1 cycle ----
        kwe_pulses = 0; we_pulse_cycles = 0;
        fork
            begin : mon_kwe
                integer c;
                for (c = 0; c < 12; c = c + 1) begin
                    @(posedge Clk); #1;
                    if (Dut.Kernel_We_Pulse) kwe_pulses = kwe_pulses + 1;
                end
            end
            axi_write(5'h14, {24'h0, 8'sd7});
        join
        check(kwe_pulses == 1, "TIM-08: Kernel_We pulses for exactly 1 cycle on a 0x14 (KERNEL_WDATA) write");
        check(s_axi_bresp == 2'b00, "TIM-08: BRESP is OKAY for a valid 0x14 write");

        // ---- ERR-06: write/read an undecoded address (0x1C) -> OKAY, no side effect ----
        axi_write(5'h1C, 32'hDEADBEEF);
        check(s_axi_bresp == 2'b00, "ERR-06: BRESP is OKAY for an undecoded write address (0x1C), no SLVERR/DECERR");
        check(Dut.Busy_w == 1'b0, "ERR-06: undecoded-address write caused no internal side effect (Busy still 0)");
        axi_read(5'h1C);
        check(rresp_capture == 2'b00, "ERR-06: RRESP is OKAY for an undecoded read address (0x1C)");
        check(rd_capture == 32'h0, "ERR-06: undecoded-address read returns 0 (default case), no hang");

        // ---- ERR-07: read OUT_DATA (0x18) while nothing has ever been valid ----
        // Out_Rd_En must still pulse unconditionally (no Out_Valid guard on the
        // AXI side), and the transaction must still complete with OKAY (no hang).
        fork
            begin : mon_rden_empty
                integer c;
                we_pulse_cycles = 0;
                for (c = 0; c < 12; c = c + 1) begin
                    @(posedge Clk); #1;
                    if (Dut.Out_Rd_En_Pulse) we_pulse_cycles = we_pulse_cycles + 1;
                end
            end
            axi_read(5'h18);
        join
        check(we_pulse_cycles == 1, "ERR-07: Out_Rd_En pulses unconditionally on a 0x18 read even while empty");
        check(rresp_capture == 2'b00, "ERR-07: RRESP is OKAY when reading 0x18 while empty (no hang/error)");

        // ---- Load a real frame via AXI so TIM-09 checks a genuine result ----
        for (I=0;I<Total_Pix;I=I+1) begin
            axi_write(5'h08, {26'h0, I[Addrw-1:0]});      // IMG_WADDR
            axi_write(5'h0C, {24'h0, Image_Stim[I]});     // IMG_WDATA -> pulses Img_We
        end
        for (I=0;I<Num_K;I=I+1) begin
            axi_write(5'h10, {28'h0, I[Kidxw-1:0]});      // KERNEL_WINDEX
            axi_write(5'h14, {{(32-Kernel_W){Kernel_K[I][Kernel_W-1]}}, Kernel_K[I]}); // KERNEL_WDATA
        end
        axi_write(5'h00, 32'h1);                          // CONTROL: Start=1, Relu_En=0

        // Wait until the raw DUT reports a result is queued (Out_Valid_w=1).
        wr_timeout = 0;
        while (!Dut.Out_Valid_w && wr_timeout < 200) begin
            @(negedge Clk); wr_timeout = wr_timeout + 1;
        end
        check(Dut.Out_Valid_w == 1'b1, "setup: a real result became available for the TIM-09 read (test precondition)");
        expected_out0 = Dut.Out_Data0_w;

        // ---- TIM-09: OUT_DATA (0x18) read handshake returns Out_Data0, sign-extended ----
        axi_read(5'h18);
        check(rresp_capture == 2'b00, "TIM-09: RRESP is OKAY for a 0x18 read with a real result present");
        check(rd_capture == {{(32-Acc_W){expected_out0[Acc_W-1]}}, expected_out0},
              "TIM-09: RDATA on a 0x18 read equals Out_Data0 sign-extended to 32 bits");

        // ---- CONTROL (0x00) readback: Busy/Scan_Done/Out_Full/Out_Valid/Relu_En bits ----
        axi_read(5'h00);
        check(rresp_capture == 2'b00, "sanity: CONTROL (0x00) read returns OKAY");

        $display("TB_AXI_LITE: %0d PASS, %0d FAIL", pass_count, fail_count);
        $finish;
    end
endmodule

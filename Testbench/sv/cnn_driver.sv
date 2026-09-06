//==============================================================================
// cnn_driver.sv | Class: cnn_driver
// Drives RTL/top.v through cnn_if.DRV. Owns every pin-level primitive
// (reset, image/kernel load, Start, output drain) plus the handful of
// protocol-bending sequences the reset/back-to-back/error test cases need.
// Reused primitives keep each scenario branch short.
//==============================================================================
import cnn_pkg::*;

class cnn_driver;
  virtual cnn_if.DRV vif;
  int img_addrw, kidxw;

  function new(virtual cnn_if.DRV vif, int img_addrw, int kidxw);
    this.vif       = vif;
    this.img_addrw = img_addrw;
    this.kidxw     = kidxw;
  endfunction

  task automatic idle_drive();
    vif.drv_cb.Start         <= 0;
    vif.drv_cb.Relu_En       <= 0;
    vif.drv_cb.Img_We        <= 0;
    vif.drv_cb.Img_Waddr     <= '0;
    vif.drv_cb.Img_Wdata     <= '0;
    vif.drv_cb.Kernel_We     <= 0;
    vif.drv_cb.Kernel_Windex <= '0;
    vif.drv_cb.Kernel_Wdata  <= '0;
    vif.drv_cb.Out_Rd_En     <= 0;
  endtask

  // RST-01/02/03/04: synchronous-style reset pulse (Rst_N is an async input
  // on the DUT; the testbench drives it, it does not use the clocking block).
  task automatic apply_reset(int cycles = 3);
    force_rst_n(1'b0);
    idle_drive();
    repeat (cycles) @(vif.drv_cb);
    force_rst_n(1'b1);
    @(vif.drv_cb);
  endtask

  // Rst_N is driven directly (not through drv_cb, since it is asynchronous
  // and modeled as a plain interface signal bound to the DUT's reset input).
  task automatic force_rst_n(bit v);
    vif.Rst_N = v;
  endtask

  task automatic write_image(bit [PIXEL_W-1:0] img[], int w, int h, bit wrap_extra = 0);
    int total;
    total = w*h;
    for (int i = 0; i < total; i++) begin
      vif.drv_cb.Img_We    <= 1;
      vif.drv_cb.Img_Waddr <= i[img_addrw-1:0];
      vif.drv_cb.Img_Wdata <= img[i];
      @(vif.drv_cb);
    end
    if (wrap_extra) begin // ERR-01: address deliberately beyond Total_Pix, wraps per fixed width
      vif.drv_cb.Img_We    <= 1;
      vif.drv_cb.Img_Waddr <= (total + 5);   // implicit truncation to img_addrw bits
      vif.drv_cb.Img_Wdata <= img[0] ^ 8'hFF;
      @(vif.drv_cb);
      $display("[DRV] ERR-01: wrapped write issued at raw address %0d (wraps to %0d)",
                total+5, (total+5) % (1<<img_addrw));
    end
    vif.drv_cb.Img_We <= 0;
    @(vif.drv_cb);
  endtask

  task automatic write_kernel(bit signed [KERNEL_W-1:0] ker[], int k, bit only_last = 0,
                               bit oob_index = 0);
    int n;
    n = k*k;
    if (oob_index) begin // ERR-02: Kernel_Windex driven outside the valid 0..n-1 range
      vif.drv_cb.Kernel_We     <= 1;
      vif.drv_cb.Kernel_Windex <= (1 << kidxw) - 1; // max representable index, out of range for this K
      vif.drv_cb.Kernel_Wdata  <= 8'sd77;
      @(vif.drv_cb);
      vif.drv_cb.Kernel_We <= 0;
      @(vif.drv_cb);
      $display("[DRV] ERR-02: out-of-range Kernel_Windex=%0d driven (valid range is 0..%0d)",
                (1<<kidxw)-1, n-1);
    end
    for (int i = 0; i < n; i++) begin
      if (only_last && i != n-1) continue;
      vif.drv_cb.Kernel_We     <= 1;
      vif.drv_cb.Kernel_Windex <= i[kidxw-1:0];
      vif.drv_cb.Kernel_Wdata  <= ker[i];
      @(vif.drv_cb);
    end
    vif.drv_cb.Kernel_We <= 0;
    @(vif.drv_cb);
  endtask

  // Common path shared by every plain (non-scenario-special) frame: load,
  // run, drain. Most test-plan rows reduce to one or two calls of this.
  task automatic run_one(cnn_frame_s f, int w, int h, int k, ref longint signed captured[$]);
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En <= f.relu_en;
    start_pulse();
    drain(captured);
  endtask

  task automatic start_pulse();
    vif.drv_cb.Start <= 1;
    @(vif.drv_cb);
    vif.drv_cb.Start <= 0;
  endtask

  // Drains Out_Data until Busy has been low and the FIFO empty for
  // IDLE_MARGIN consecutive cycles - i.e. every produced result was popped.
  task automatic drain(ref longint signed captured[$], input int max_cycles = 200000);
    int idle_count, cyc;
    localparam int IDLE_MARGIN = 8;
    captured.delete();
    idle_count = 0;
    cyc = 0;
    vif.drv_cb.Out_Rd_En <= 1;
    while (idle_count < IDLE_MARGIN && cyc < max_cycles) begin
      @(vif.drv_cb);
      cyc++;
      if (vif.drv_cb.Out_Valid) captured.push_back(longint'(vif.drv_cb.Out_Data));
      if (!vif.drv_cb.Busy && !vif.drv_cb.Out_Valid) idle_count++;
      else idle_count = 0;
    end
    vif.drv_cb.Out_Rd_En <= 0;
  endtask

  // ERR-03: attempt a read while the FIFO is provably empty (before any run).
  task automatic read_when_empty(int cycles = 5);
    vif.drv_cb.Out_Rd_En <= 1;
    repeat (cycles) begin
      @(vif.drv_cb);
      if (vif.drv_cb.Out_Valid)
        $display("[DRV][WARN] ERR-03: Out_Valid unexpectedly high while FIFO should be empty");
    end
    vif.drv_cb.Out_Rd_En <= 0;
    @(vif.drv_cb);
    $display("[DRV] ERR-03: read-while-empty probe complete, no false Out_Valid observed");
  endtask

  // ERR-04: hold the consumer off so the FIFO (Out_Depth=16) fills and
  // Out_Full asserts; only start draining after the whole scan is done.
  task automatic run_and_stall_then_drain(cnn_frame_s f, int w, int h, int k,
                                           ref longint signed captured[$]);
    bit seen_full;
    seen_full = 0;
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En   <= f.relu_en;
    vif.drv_cb.Out_Rd_En <= 0;
    start_pulse();
    while (vif.drv_cb.Busy) begin
      @(vif.drv_cb);
      if (vif.drv_cb.Out_Full) seen_full = 1;
    end
    repeat (4) @(vif.drv_cb);
    $display("[DRV] ERR-04: Out_Full observed during stalled scan = %0b", seen_full);
    drain(captured);
    $display("[DRV] ERR-04: %0d results recoverable after a %0d-deep FIFO stalled the consumer",
              captured.size(), 16);
  endtask

  // RST-02: abort a scan halfway through by asserting reset mid-Busy.
  task automatic reset_mid_scan(cnn_frame_s f, int w, int h, int k);
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En <= f.relu_en;
    start_pulse();
    repeat ((w*h)/2) @(vif.drv_cb);
    apply_reset(3);
    if (vif.drv_cb.Busy || vif.drv_cb.Out_Valid)
      $display("[DRV][FAIL] RST-02: Busy/Out_Valid still asserted after reset release");
    else
      $display("[DRV] RST-02: Busy/Out_Valid cleanly deasserted after a mid-scan reset");
  endtask

  // RST-03: let results queue up unread, then reset with data pending.
  task automatic reset_with_fifo_pending(cnn_frame_s f, int w, int h, int k);
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En   <= f.relu_en;
    vif.drv_cb.Out_Rd_En <= 0;
    start_pulse();
    while (!vif.drv_cb.Out_Valid) @(vif.drv_cb);
    repeat (5) @(vif.drv_cb); // let a few more queue up
    apply_reset(3);
    if (vif.drv_cb.Out_Valid)
      $display("[DRV][FAIL] RST-03: Out_Valid still high after reset with pending FIFO data");
    else
      $display("[DRV] RST-03: FIFO correctly reports empty (Out_Valid=0) after reset");
  endtask

  // B2B-02: fire a second Start while the first scan is still Busy.
  task automatic start_while_busy(cnn_frame_s f, int w, int h, int k, ref longint signed captured[$]);
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En <= f.relu_en;
    start_pulse();
    repeat ((w*h)/3) @(vif.drv_cb);
    vif.drv_cb.Start <= 1;              // spurious Start while Busy=1 - controller.v only samples Start in S_Idle
    @(vif.drv_cb);
    vif.drv_cb.Start <= 0;
    drain(captured);
  endtask

  // B2B-01: reassert Start on the cycle immediately following Scan_Done (the
  // tightest possible back-to-back restart), reusing the same image/kernel
  // already resident in memory - no reload, so nothing but the FSM itself
  // gates how soon the second scan can begin.
  task automatic zero_gap_restart(cnn_frame_s f, int w, int h, int k,
                                   ref longint signed cap0[$], ref longint signed cap1[$]);
    bit start_reissued, start_cleared, restarted;
    int idle_count;
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En   <= f.relu_en;
    vif.drv_cb.Out_Rd_En <= 1;
    cap0.delete(); cap1.delete();
    start_reissued = 0; start_cleared = 0; restarted = 0; idle_count = 0;
    start_pulse();
    forever begin
      @(vif.drv_cb);
      if (vif.drv_cb.Out_Valid) begin
        if (!restarted) cap0.push_back(longint'(vif.drv_cb.Out_Data));
        else             cap1.push_back(longint'(vif.drv_cb.Out_Data));
      end
      if (vif.drv_cb.Scan_Done && !start_reissued) begin
        vif.drv_cb.Start <= 1;   // driven now -> sampled by the DUT on the very next edge
        start_reissued = 1;
      end else if (start_reissued && !start_cleared) begin
        vif.drv_cb.Start <= 0;
        start_cleared = 1;
        restarted = 1;
      end
      if (restarted) begin
        if (!vif.drv_cb.Busy && !vif.drv_cb.Out_Valid) idle_count++;
        else idle_count = 0;
        if (idle_count >= 8) break;
      end
    end
    vif.drv_cb.Out_Rd_En <= 0;
    $display("[DRV] B2B-01: Start reasserted the cycle immediately after Scan_Done (zero-gap restart)");
  endtask

  // ERR-05: toggle a write-enable mid-scan.
  task automatic write_during_busy(cnn_frame_s f, int w, int h, int k, ref longint signed captured[$]);
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En <= f.relu_en;
    start_pulse();
    repeat ((w*h)/2) @(vif.drv_cb);
    vif.drv_cb.Kernel_We     <= 1;
    vif.drv_cb.Kernel_Windex <= '0;
    vif.drv_cb.Kernel_Wdata  <= 8'sd5;
    @(vif.drv_cb);
    vif.drv_cb.Kernel_We <= 0;
    drain(captured);
  endtask

  // TIM-01: measure Start-to-Busy latency in cycles.
  task automatic measure_start_to_busy(cnn_frame_s f, int w, int h, int k, output int latency_cycles);
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En <= f.relu_en;
    vif.drv_cb.Start <= 1;
    @(vif.drv_cb);
    vif.drv_cb.Start <= 0;
    latency_cycles = 0;
    while (!vif.drv_cb.Busy && latency_cycles < 10) begin @(vif.drv_cb); latency_cycles++; end
  endtask

  // TIM-02: measure Start-to-first-Out_Valid pipeline latency.
  task automatic measure_pipe_latency(cnn_frame_s f, int w, int h, int k, output int latency_cycles,
                                       ref longint signed captured[$]);
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En   <= f.relu_en;
    vif.drv_cb.Out_Rd_En <= 1;
    start_pulse();
    latency_cycles = 0;
    while (!vif.drv_cb.Out_Valid && latency_cycles < (w*h)) begin @(vif.drv_cb); latency_cycles++; end
    drain(captured);
  endtask

  // TIM-06: verify Out_Data/Out_Valid hold steady while Out_Rd_En stays low.
  task automatic hold_no_read_check(cnn_frame_s f, int w, int h, int k, ref longint signed captured[$]);
    logic signed [ACC_W-1:0] held;
    bit stable;
    write_image(f.image, w, h);
    write_kernel(f.kernel, k);
    vif.drv_cb.Relu_En   <= f.relu_en;
    vif.drv_cb.Out_Rd_En <= 0;
    start_pulse();
    while (!vif.drv_cb.Out_Valid) @(vif.drv_cb);
    held = vif.drv_cb.Out_Data;
    stable = 1;
    repeat (10) begin
      @(vif.drv_cb);
      if (!vif.drv_cb.Out_Valid || vif.drv_cb.Out_Data !== held) stable = 0;
    end
    if (stable) $display("[DRV] TIM-06: Out_Data/Out_Valid held stable for 10 cycles with no read");
    else        $display("[DRV][FAIL] TIM-06: Out_Data/Out_Valid changed without a read");
    drain(captured);
  endtask

endclass

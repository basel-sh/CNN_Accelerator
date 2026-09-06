//==============================================================================
// cnn_monitor.sv | Class: cnn_monitor
// Passive observer: runs for the whole simulation alongside the driver,
// sampling functional coverage and continuously checking the protocol
// invariants behind TIM-03/04/05 (Raw_Valid gating, Scan_Done pulse width,
// gap-free address sequencing) on every frame any test drives, using the
// whitebox probes tb_top_sv.sv wires up from RTL/controller.v.
//==============================================================================
import cnn_pkg::*;

class cnn_monitor;
  virtual cnn_if.MON vif;
  int img_w, img_h, k;
  int protocol_errors = 0;

  // ---- functional coverage: protocol/timing (sampled every clock) ----
  // Sampled explicitly (once per clock, from run() below) rather than on an
  // implicit clocking event, so there is exactly one sample() call per cycle.
  covergroup cg_protocol;
    cp_state:     coverpoint vif.mon_cb.wb_state     { bins idle=(2'd0); bins run=(2'd1); bins done=(2'd2); }
    cp_busy:      coverpoint vif.mon_cb.Busy;
    cp_out_valid: coverpoint vif.mon_cb.Out_Valid;
    cp_out_full:  coverpoint vif.mon_cb.Out_Full;
    cp_raw_valid: coverpoint vif.mon_cb.wb_raw_valid;
    cx_state_raw: cross cp_state, cp_raw_valid;
    cx_valid_full: cross cp_out_valid, cp_out_full;
  endgroup

  function new(virtual cnn_if.MON vif, int img_w, int img_h, int k);
    this.vif   = vif;
    this.img_w = img_w;
    this.img_h = img_h;
    this.k     = k;
    cg_protocol = new();
  endfunction

  task automatic run();
    int addr_count, raw_valid_count, scan_done_run, last_raddr;
    bit have_last, prev_start;
    addr_count = 0; raw_valid_count = 0; scan_done_run = 0; have_last = 0; prev_start = 0;
    forever begin
      @(vif.mon_cb);

      // reset per-frame counters on the rising edge of Start
      if (vif.mon_cb.Start && !prev_start) begin
        addr_count = 0; raw_valid_count = 0; have_last = 0;
      end
      prev_start = vif.mon_cb.Start;

      if (vif.mon_cb.wb_streaming) begin
        addr_count++;
        if (have_last && vif.mon_cb.wb_mem_raddr != last_raddr + 1'b1 &&
            last_raddr != (img_w*img_h - 1)) begin
          protocol_errors++;
          $display("[MON][FAIL] TIM-05: non-sequential Mem_Raddr %0d after %0d",
                    vif.mon_cb.wb_mem_raddr, last_raddr);
        end
        last_raddr = vif.mon_cb.wb_mem_raddr;
        have_last  = 1;
        if (vif.mon_cb.wb_raw_valid) raw_valid_count++;
      end

      // TIM-03: Raw_Valid must never assert outside an active streaming cycle
      if (vif.mon_cb.wb_raw_valid && !vif.mon_cb.wb_streaming) begin
        protocol_errors++;
        $display("[MON][FAIL] TIM-03: Raw_Valid asserted while Streaming=0");
      end

      // TIM-04: Scan_Done must be a single-cycle pulse
      if (vif.mon_cb.Scan_Done) scan_done_run++; else scan_done_run = 0;
      if (scan_done_run > 1) begin
        protocol_errors++;
        $display("[MON][FAIL] TIM-04: Scan_Done held high for >1 cycle");
      end

      if (vif.mon_cb.Scan_Done) begin
        int exp_addr, exp_valid;
        exp_addr  = img_w*img_h;
        exp_valid = (img_w-k+1)*(img_h-k+1);
        if (addr_count == exp_addr)
          $display("[MON] TIM-05: address count OK (%0d == %0d)", addr_count, exp_addr);
        else begin
          protocol_errors++;
          $display("[MON][FAIL] TIM-05: address count %0d != expected %0d", addr_count, exp_addr);
        end
        if (raw_valid_count == exp_valid)
          $display("[MON] TIM-03: Raw_Valid count OK (%0d == %0d)", raw_valid_count, exp_valid);
        else begin
          protocol_errors++;
          $display("[MON][FAIL] TIM-03: Raw_Valid count %0d != expected %0d", raw_valid_count, exp_valid);
        end
      end

      cg_protocol.sample();
    end
  endtask

  function real protocol_coverage();
    return cg_protocol.get_coverage();
  endfunction
endclass

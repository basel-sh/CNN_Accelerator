//==============================================================================
// cnn_env.sv | Class: cnn_env
// Builds the driver/monitor/scoreboard, iterates cnn_pkg::build_test_list(),
// and dispatches each test's scenario to the right driver sequence + golden
// compare. This is the only place that knows how a scenario maps to pin
// wiggling + checking - drivers/scoreboard stay generic and reusable.
//==============================================================================
import cnn_pkg::*;

class cnn_env;
  virtual cnn_if.DRV dvif;
  virtual cnn_if.MON mvif;
  cnn_driver     drv;
  cnn_monitor    mon;
  cnn_scoreboard sb;
  int img_addrw, kidxw;

  function new(virtual cnn_if.DRV dvif, virtual cnn_if.MON mvif, int img_addrw, int kidxw,
               int default_w, int default_h, int default_k);
    this.dvif = dvif;
    this.mvif = mvif;
    this.img_addrw = img_addrw;
    this.kidxw = kidxw;
    drv = new(dvif, img_addrw, kidxw);
    mon = new(mvif, default_w, default_h, default_k);
    sb  = new();
  endfunction

  task automatic run();
    cnn_txn tests[$];
    build_test_list(tests);
    drv.apply_reset();
    fork
      mon.run();
    join_none

    foreach (tests[ti]) begin
      dispatch(tests[ti]);
      sb.sample_scenario(tests[ti]);
    end

    $display("");
    $display("Monitor whitebox protocol-check errors (TIM-03/04/05, all frames): %0d", mon.protocol_errors);
    $display("Monitor protocol functional coverage: %0.1f%%", mon.protocol_coverage());
    sb.print_summary();
  endtask

  task automatic dispatch(cnn_txn t);
    longint signed cap_q[$];
    longint signed cap_a[], exp_a[];
    int lat;

    case (t.scenario)

      SCN_NORMAL: begin
        drv.apply_reset();
        drv.run_one(t.frames[0], t.img_w, t.img_h, t.k, cap_q);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame(t.test_id, t.description, exp_a, cap_a, t.expect_data_check);
      end

      SCN_RESET_MID_SCAN: begin
        drv.apply_reset();
        drv.reset_mid_scan(t.frames[0], t.img_w, t.img_h, t.k);
        sb.note_observed(t.test_id, "mid-scan reset protocol check performed by the driver (see [DRV] log lines above)");
      end

      SCN_RESET_FIFO_PENDING: begin
        drv.apply_reset();
        drv.reset_with_fifo_pending(t.frames[0], t.img_w, t.img_h, t.k);
        sb.note_observed(t.test_id, "reset-with-pending-FIFO check performed by the driver (see [DRV] log lines above)");
      end

      SCN_RESET_REPEAT: begin
        drv.apply_reset();
        drv.run_one(t.frames[0], t.img_w, t.img_h, t.k, cap_q);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame({t.test_id, ".1"}, t.description, exp_a, cap_a, 1);

        drv.apply_reset();
        drv.run_one(t.frames[1], t.img_w, t.img_h, t.k, cap_q);
        golden_frame(t.frames[1], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame({t.test_id, ".2"}, {t.description, " (after a second reset)"}, exp_a, cap_a, 1);
      end

      SCN_RESET_NO_REPROGRAM: begin
        cnn_frame_s zf;
        drv.apply_reset();
        drv.write_image(t.frames[0].image, t.img_w, t.img_h);
        drv.write_kernel(t.frames[0].kernel, t.k);
        drv.apply_reset(); // kernel_memory.v's Rst_N clears Coeff[] - image_memory/ram.v has no reset, image persists
        drv.start_pulse();
        drv.drain(cap_q);
        zf.image = t.frames[0].image;
        zf.kernel = new[t.k*t.k];
        foreach (zf.kernel[i]) zf.kernel[i] = 0;
        zf.relu_en = t.frames[0].relu_en;
        golden_frame(zf, t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame(t.test_id, {t.description, " (expect all-zero-kernel result: kernel_memory clears on reset, image_memory does not)"},
                        exp_a, cap_a, 1);
      end

      SCN_ZERO_GAP_RESTART: begin
        longint signed cap_q2[$], cap_a2[];
        drv.apply_reset();
        drv.zero_gap_restart(t.frames[0], t.img_w, t.img_h, t.k, cap_q, cap_q2);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame({t.test_id, ".1"}, t.description, exp_a, cap_a, 1);

        queue_to_array(cap_q2, cap_a2);
        sb.check_frame({t.test_id, ".2"}, {t.description, " (zero-gap restart, same image/kernel, no reload/reset)"}, exp_a, cap_a2, 1);
      end

      SCN_START_WHILE_BUSY: begin
        drv.apply_reset();
        drv.start_while_busy(t.frames[0], t.img_w, t.img_h, t.k, cap_q);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame(t.test_id, {t.description, " (spurious mid-scan Start must not disturb the active scan)"}, exp_a, cap_a, 1);
      end

      SCN_KERNEL_SWITCH_B2B: begin
        drv.apply_reset();
        drv.run_one(t.frames[0], t.img_w, t.img_h, t.k, cap_q);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame({t.test_id, ".1"}, t.description, exp_a, cap_a, 1);

        drv.write_kernel(t.frames[1].kernel, t.k); // image memory retains frame0's image (same seed) - only kernel reloaded
        drv.start_pulse();
        drv.drain(cap_q);
        golden_frame(t.frames[1], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame({t.test_id, ".2"}, {t.description, " (kernel reloaded, no reset)"}, exp_a, cap_a, 1);
      end

      SCN_MULTI_FRAME3: begin
        drv.apply_reset();
        foreach (t.frames[i]) begin
          drv.run_one(t.frames[i], t.img_w, t.img_h, t.k, cap_q);
          golden_frame(t.frames[i], t.img_w, t.img_h, t.k, exp_a);
          queue_to_array(cap_q, cap_a);
          sb.check_frame($sformatf("%s.%0d", t.test_id, i+1), t.description, exp_a, cap_a, 1);
        end
      end

      SCN_ADDR_WRAP: begin
        drv.apply_reset();
        drv.write_image(t.frames[0].image, t.img_w, t.img_h, 1'b1);
        drv.write_kernel(t.frames[0].kernel, t.k);
        drv.start_pulse();
        drv.drain(cap_q);
        sb.note_observed(t.test_id, $sformatf("scan completed with no hang/X after a wrapped image-write address (%0d results captured)", cap_q.size()));
      end

      SCN_KERNEL_IDX_OOB: begin
        drv.apply_reset();
        drv.write_image(t.frames[0].image, t.img_w, t.img_h);
        drv.write_kernel(t.frames[0].kernel, t.k, 1'b0, 1'b1); // OOB probe write, then the real kernel loaded normally
        drv.start_pulse();
        drv.drain(cap_q);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame(t.test_id, {t.description, " (post-recovery correctness after the OOB probe)"}, exp_a, cap_a, 1);
      end

      SCN_READ_WHEN_EMPTY: begin
        drv.apply_reset();
        drv.read_when_empty();
        drv.run_one(t.frames[0], t.img_w, t.img_h, t.k, cap_q);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame(t.test_id, {t.description, " (post-probe correctness)"}, exp_a, cap_a, 1);
      end

      SCN_FIFO_FULL: begin
        drv.apply_reset();
        drv.run_and_stall_then_drain(t.frames[0], t.img_w, t.img_h, t.k, cap_q);
        sb.note_observed(t.test_id, $sformatf("%0d of %0d results recoverable once the 16-deep FIFO saturated - documents the throughput limit",
                          cap_q.size(), (t.img_w-t.k+1)*(t.img_h-t.k+1)));
      end

      SCN_WRITE_DURING_BUSY: begin
        drv.apply_reset();
        drv.write_during_busy(t.frames[0], t.img_w, t.img_h, t.k, cap_q);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame(t.test_id, t.description, exp_a, cap_a, t.expect_data_check);
      end

      SCN_HOLD_NO_READ: begin
        drv.apply_reset();
        drv.hold_no_read_check(t.frames[0], t.img_w, t.img_h, t.k, cap_q);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame(t.test_id, t.description, exp_a, cap_a, 1);
      end

      SCN_KERNEL_WINDEX_MAX: begin
        drv.apply_reset();
        drv.write_image(t.frames[0].image, t.img_w, t.img_h);
        drv.write_kernel(t.frames[0].kernel, t.k, 1'b1); // only the last coefficient is written; rest stay reset-cleared at 0
        drv.start_pulse();
        drv.drain(cap_q);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a); // frames[0].kernel already models "only last tap nonzero"
        queue_to_array(cap_q, cap_a);
        sb.check_frame(t.test_id, t.description, exp_a, cap_a, 1);
      end

      SCN_PIPE_LATENCY: begin
        drv.apply_reset();
        drv.measure_pipe_latency(t.frames[0], t.img_w, t.img_h, t.k, lat, cap_q);
        $display("[ENV][%s] measured Start-to-first-Out_Valid latency = %0d cycles", t.test_id, lat);
        golden_frame(t.frames[0], t.img_w, t.img_h, t.k, exp_a);
        queue_to_array(cap_q, cap_a);
        sb.check_frame(t.test_id, $sformatf("%s (measured latency = %0d cycles)", t.description, lat), exp_a, cap_a, 1);
      end

      SCN_START_TO_BUSY: begin
        drv.apply_reset();
        drv.measure_start_to_busy(t.frames[0], t.img_w, t.img_h, t.k, lat);
        if (lat == 1) sb.note_pass(t.test_id, "Busy asserted exactly 1 cycle after Start");
        else          sb.note_fail(t.test_id, $sformatf("Busy asserted after %0d cycles (expected 1)", lat));
        drv.drain(cap_q); // flush the frame that was implicitly started; not data-checked here
      end

      default: sb.note_observed(t.test_id, "unhandled scenario (should not happen)");
    endcase
  endtask

endclass

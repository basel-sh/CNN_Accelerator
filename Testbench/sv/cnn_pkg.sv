//==============================================================================
// cnn_pkg.sv | Package: cnn_pkg
// Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026 (Team: Silicon Minds)
//
// Shared types, the bit-accurate SystemVerilog golden model (mirrors
// Python/golden_model.py exactly: unsigned pixel / signed kernel / signed
// saturating accumulator / optional ReLU, valid convolution, stride 1),
// stimulus generators, the transaction class, and the master test table that
// drives every case in Documentation/../Verification_Test_Plan.xlsx.
//==============================================================================
package cnn_pkg;

  // ---- DUT-matching defaults (RTL/top.v parameter defaults) -----------------
  parameter int PIXEL_W  = 8;
  parameter int KERNEL_W = 8;
  parameter int ACC_W    = 20;

  // ---- stimulus taxonomy ------------------------------------------------
  typedef enum { PAT_FILE, PAT_ZEROS, PAT_MAX, PAT_CHECKER, PAT_RANDOM,
                 PAT_CORNER_TL, PAT_CORNER_BR } img_pattern_e;

  typedef enum { KER_IDENTITY, KER_EDGE, KER_ALL_ZERO, KER_RANDOM,
                 KER_MAX_POS, KER_MAX_NEG, KER_SUM_ONES, KER_LAST_ONLY } ker_pattern_e;

  // scenario_e picks which driver sequence runs a test's frame(s).
  typedef enum { SCN_NORMAL, SCN_RESET_MID_SCAN, SCN_RESET_FIFO_PENDING,
                 SCN_RESET_REPEAT, SCN_RESET_NO_REPROGRAM, SCN_ZERO_GAP_RESTART,
                 SCN_START_WHILE_BUSY, SCN_KERNEL_SWITCH_B2B, SCN_MULTI_FRAME3,
                 SCN_ADDR_WRAP, SCN_KERNEL_IDX_OOB, SCN_WRITE_DURING_BUSY,
                 SCN_READ_WHEN_EMPTY, SCN_FIFO_FULL, SCN_HOLD_NO_READ,
                 SCN_KERNEL_WINDEX_MAX, SCN_PIPE_LATENCY, SCN_START_TO_BUSY
               } scenario_e;

  // one frame = one image + one kernel + one relu setting, loaded & run once
  typedef struct {
    bit [PIXEL_W-1:0]        image[];   // row-major, size img_w*img_h
    bit signed [KERNEL_W-1:0] kernel[]; // row-major, size k*k
    bit                       relu_en;
    img_pattern_e             img_pat;  // retained for functional-coverage sampling
    ker_pattern_e             ker_pat;
  } cnn_frame_s;

  //---------------------------------------------------------------------------
  // Saturate a wide signed sum into `width` signed bits (matches
  // Python/utilities.py:quantize_signed - saturating, not wrapping).
  //---------------------------------------------------------------------------
  function automatic longint signed saturate_signed(input longint signed v, input int width);
    longint signed lo, hi;
    lo = -(longint'(1) <<< (width-1));
    hi =  (longint'(1) <<< (width-1)) - 1;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  endfunction

  //---------------------------------------------------------------------------
  // Bit-accurate golden model: one output pixel. Mirrors
  // Python/convolution.py + Python/golden_model.py exactly.
  //---------------------------------------------------------------------------
  function automatic longint signed golden_pixel(
      input bit [PIXEL_W-1:0]        image[], input int img_w,
      input bit signed [KERNEL_W-1:0] kernel[], input int k,
      input int out_row, input int out_col, input bit relu_en);
    longint signed sum;
    sum = 0;
    for (int r = 0; r < k; r++)
      for (int c = 0; c < k; c++)
        sum += longint'(image[(out_row+r)*img_w + (out_col+c)]) * longint'(kernel[r*k+c]);
    sum = saturate_signed(sum, ACC_W);
    if (relu_en && sum < 0) sum = 0;
    return sum;
  endfunction

  // Full-frame golden reference, returned row-major, size (h-k+1)*(w-k+1).
  function automatic void golden_frame(input cnn_frame_s f, input int w, input int h, input int k,
                                        output longint signed exp_out[]);
    int out_w, out_h, idx;
    out_w = w - k + 1;
    out_h = h - k + 1;
    exp_out = new[out_w*out_h];
    idx = 0;
    for (int r = 0; r < out_h; r++)
      for (int c = 0; c < out_w; c++) begin
        exp_out[idx] = golden_pixel(f.image, w, f.kernel, k, r, c, f.relu_en);
        idx++;
      end
  endfunction

  //---------------------------------------------------------------------------
  // Stimulus generators (SV equivalents of Python/image_generator.py)
  //---------------------------------------------------------------------------
  function automatic void gen_image(output bit [PIXEL_W-1:0] img[], input int w, input int h,
                                     input img_pattern_e pat, input int seed);
    img = new[w*h];
    void'($urandom(seed));
    case (pat)
      PAT_ZEROS:   foreach (img[i]) img[i] = '0;
      PAT_MAX:     foreach (img[i]) img[i] = {PIXEL_W{1'b1}};
      PAT_CHECKER: for (int r = 0; r < h; r++) for (int c = 0; c < w; c++)
                     img[r*w+c] = (((r+c) % 2) == 0) ? {PIXEL_W{1'b1}} : '0;
      PAT_RANDOM:  foreach (img[i]) img[i] = $urandom_range(0, (1<<PIXEL_W)-1);
      PAT_CORNER_TL: begin foreach (img[i]) img[i] = '0; img[0] = {PIXEL_W{1'b1}}; end
      PAT_CORNER_BR: begin foreach (img[i]) img[i] = '0; img[w*h-1] = {PIXEL_W{1'b1}}; end
      PAT_FILE: begin
        // Falls back to the project's proven real-image stimulus (default 32x32).
        $readmemh("Images/input_32x32.mem", img);
      end
      default: foreach (img[i]) img[i] = '0;
    endcase
  endfunction

  function automatic void gen_kernel(output bit signed [KERNEL_W-1:0] ker[], input int k,
                                      input ker_pattern_e pat, input int seed);
    int n, maxpos, maxneg;
    n = k*k;
    ker = new[n];
    void'($urandom(seed));
    maxpos = (1 << (KERNEL_W-1)) - 1;   // +127 for 8-bit
    maxneg = -(1 << (KERNEL_W-1));      // -128 for 8-bit
    case (pat)
      KER_IDENTITY:  begin foreach (ker[i]) ker[i] = '0; ker[(k/2)*k + (k/2)] = 1; end
      KER_EDGE: begin // 3x3 vertical Sobel, same coefficients as Images/kernels/edge_3x3.mem
        if (k == 3) ker = '{-8'sd1, 8'sd0, 8'sd1, -8'sd2, 8'sd0, 8'sd2, -8'sd1, 8'sd0, 8'sd1};
        else foreach (ker[i]) ker[i] = (i == 0) ? 1 : -1; // generic fallback for K!=3
      end
      KER_ALL_ZERO: foreach (ker[i]) ker[i] = '0;
      KER_RANDOM:   foreach (ker[i]) ker[i] = $urandom_range(maxneg, maxpos);
      KER_MAX_POS:  foreach (ker[i]) ker[i] = maxpos;
      KER_MAX_NEG:  foreach (ker[i]) ker[i] = maxneg;
      KER_SUM_ONES: foreach (ker[i]) ker[i] = 1;
      KER_LAST_ONLY: begin foreach (ker[i]) ker[i] = '0; ker[n-1] = 1; end
      default: foreach (ker[i]) ker[i] = '0;
    endcase
  endfunction

  // Queue -> dynamic-array helper (driver captures into a queue; the
  // scoreboard/golden model compare against a sized dynamic array).
  function automatic void queue_to_array(input longint signed q[$], output longint signed arr[]);
    arr = new[q.size()];
    foreach (q[i]) arr[i] = q[i];
  endfunction

  //---------------------------------------------------------------------------
  // Transaction: one full test-plan row. `frames` holds every image/kernel
  // pair the scenario drives, in order (most scenarios use 1-3 frames).
  //---------------------------------------------------------------------------
  class cnn_txn;
    string        test_id;
    string        description;
    int           img_w = 32, img_h = 32, k = 3;
    scenario_e    scenario = SCN_NORMAL;
    cnn_frame_s   frames[$];
    bit           expect_data_check = 1'b1; // 0 = protocol/behavior-only (documentation case)
    int           fifo_stall_frames = 0;    // extra Out_Rd_En=0 frames for FIFO-full style tests

    function new(string id, string desc = "");
      test_id     = id;
      description = desc;
    endfunction

    function void add_frame(img_pattern_e ip, int iseed, ker_pattern_e kp, int kseed, bit relu);
      cnn_frame_s f;
      gen_image(f.image, img_w, img_h, ip, iseed);
      gen_kernel(f.kernel, k, kp, kseed);
      f.relu_en = relu;
      f.img_pat = ip;
      f.ker_pat = kp;
      frames.push_back(f);
    endfunction
  endclass

  //---------------------------------------------------------------------------
  // Master test table -> one cnn_txn per Verification_Test_Plan.xlsx row that
  // exercises the full `top` DUT through the layered environment. Unit-level
  // rows (FUNC-08 mac.v, FUNC-09 controller.v) and AXI rows (ERR-06/07,
  // TIM-08/09) run in their own dedicated programs - see mac_unit_test.sv,
  // ctrl_unit_test.sv and axi_smoke_test.sv.
  //---------------------------------------------------------------------------
  function automatic void build_test_list(output cnn_txn tests[$]);
    cnn_txn t;
    tests.delete();

    // ---------------- FUNCTIONAL ----------------
    t = new("FUNC-01", "identity kernel reproduces the input image");
    t.add_frame(PAT_FILE, 0, KER_IDENTITY, 0, 0); tests.push_back(t);

    t = new("FUNC-02", "Sobel edge kernel, ReLU off (matches the proven 900/900 case)");
    t.add_frame(PAT_FILE, 0, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("FUNC-03", "Sobel edge kernel, ReLU on - negative results clamp to zero");
    t.add_frame(PAT_FILE, 0, KER_EDGE, 0, 1); tests.push_back(t);

    t = new("FUNC-04", "kernel reload changes the very next run's result");
    t.scenario = SCN_KERNEL_SWITCH_B2B;
    t.add_frame(PAT_RANDOM, 10, KER_EDGE, 0, 0);
    t.add_frame(PAT_RANDOM, 10, KER_RANDOM, 11, 0);
    tests.push_back(t);

    for (int s = 0; s < 3; s++) begin
      t = new($sformatf("FUNC-05.%0d", s), "randomized regression");
      t.add_frame(PAT_RANDOM, 100+s, KER_RANDOM, 200+s, s[0]);
      tests.push_back(t);
    end

    t = new("FUNC-06", "larger-than-minimum image size (64x64)");
    t.img_w = 64; t.img_h = 64;
    t.add_frame(PAT_RANDOM, 42, KER_RANDOM, 43, 0); tests.push_back(t);

    t = new("FUNC-07", "larger kernel size (K=5)");
    t.k = 5;
    t.add_frame(PAT_RANDOM, 44, KER_RANDOM, 45, 1); tests.push_back(t);

    // ---------------- BOUNDARY / CORNER ----------------
    t = new("BND-01", "minimum spec image size, 32x32 exactly");
    t.add_frame(PAT_RANDOM, 1, KER_RANDOM, 2, 0); tests.push_back(t);

    t = new("BND-02", "smallest kernel (K=3) x largest tested image (64x64)");
    t.img_w = 64; t.img_h = 64; t.k = 3;
    t.add_frame(PAT_RANDOM, 3, KER_RANDOM, 4, 0); tests.push_back(t);

    t = new("BND-03", "all-zero image"); t.add_frame(PAT_ZEROS, 0, KER_EDGE, 0, 0); tests.push_back(t);
    t = new("BND-04", "all-max image");  t.add_frame(PAT_MAX,   0, KER_EDGE, 0, 0); tests.push_back(t);
    t = new("BND-05", "checkerboard image"); t.add_frame(PAT_CHECKER, 0, KER_RANDOM, 5, 0); tests.push_back(t);
    t = new("BND-06", "all-zero kernel"); t.add_frame(PAT_RANDOM, 6, KER_ALL_ZERO, 0, 0); tests.push_back(t);

    t = new("BND-07", "max positive accumulator magnitude (overflow boundary)");
    t.add_frame(PAT_MAX, 0, KER_MAX_POS, 0, 0); tests.push_back(t);

    t = new("BND-08", "max negative accumulator magnitude (overflow boundary)");
    t.add_frame(PAT_MAX, 0, KER_MAX_NEG, 0, 0); tests.push_back(t);

    t = new("BND-09", "ReLU boundary exactly at zero");
    t.add_frame(PAT_ZEROS, 0, KER_RANDOM, 7, 1); tests.push_back(t); // zero image -> every sum is exactly 0

    t = new("BND-10", "spatial corner windows (top-left, bottom-right)");
    t.add_frame(PAT_CORNER_TL, 0, KER_SUM_ONES, 0, 0);
    t.add_frame(PAT_CORNER_BR, 0, KER_SUM_ONES, 0, 0);
    tests.push_back(t);

    t = new("BND-11", "kernel index boundary (Windex = K*K-1)");
    t.scenario = SCN_KERNEL_WINDEX_MAX;
    t.add_frame(PAT_RANDOM, 8, KER_LAST_ONLY, 0, 0); tests.push_back(t);

    // ---------------- RESET BEHAVIOR ----------------
    t = new("RST-01", "power-on / idle reset"); t.scenario = SCN_NORMAL;
    t.add_frame(PAT_RANDOM, 20, KER_EDGE, 0, 0); tests.push_back(t); // reset_dut() always runs first

    t = new("RST-02", "reset asserted mid-scan"); t.scenario = SCN_RESET_MID_SCAN;
    t.expect_data_check = 0;
    t.add_frame(PAT_RANDOM, 21, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("RST-03", "reset with unread results pending in the FIFO"); t.scenario = SCN_RESET_FIFO_PENDING;
    t.expect_data_check = 0;
    t.add_frame(PAT_RANDOM, 22, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("RST-04", "repeated reset/run/reset/run stability"); t.scenario = SCN_RESET_REPEAT;
    t.add_frame(PAT_RANDOM, 23, KER_EDGE, 0, 0);
    t.add_frame(PAT_RANDOM, 24, KER_RANDOM, 25, 1);
    tests.push_back(t);

    t = new("RST-05", "documented: reset clears the programmed kernel"); t.scenario = SCN_RESET_NO_REPROGRAM;
    t.add_frame(PAT_RANDOM, 26, KER_EDGE, 0, 0); tests.push_back(t);

    // ---------------- BACK-TO-BACK ----------------
    t = new("B2B-01", "zero-gap restart immediately after Scan_Done"); t.scenario = SCN_ZERO_GAP_RESTART;
    t.add_frame(PAT_RANDOM, 30, KER_EDGE, 0, 0); // same image/kernel reused for both frames - no reload between them
    tests.push_back(t);

    t = new("B2B-02", "spurious Start mid-scan is ignored"); t.scenario = SCN_START_WHILE_BUSY;
    t.add_frame(PAT_RANDOM, 32, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("B2B-03", "kernel switched between back-to-back frames"); t.scenario = SCN_KERNEL_SWITCH_B2B;
    t.add_frame(PAT_RANDOM, 33, KER_EDGE, 0, 0);
    t.add_frame(PAT_RANDOM, 33, KER_RANDOM, 34, 0);
    tests.push_back(t);

    t = new("B2B-04", "three consecutive frames, consumer always draining"); t.scenario = SCN_MULTI_FRAME3;
    t.add_frame(PAT_RANDOM, 35, KER_RANDOM, 36, 0);
    t.add_frame(PAT_RANDOM, 37, KER_RANDOM, 38, 1);
    t.add_frame(PAT_RANDOM, 39, KER_EDGE,   0, 0);
    tests.push_back(t);

    // B2B-05 is a documentation-only case (no runtime resize is possible / applicable) -
    // recorded directly in the report; nothing to drive in simulation.

    // ---------------- ERROR / INVALID-INPUT ----------------
    t = new("ERR-01", "image write address wraparound"); t.scenario = SCN_ADDR_WRAP;
    t.expect_data_check = 0;
    t.add_frame(PAT_RANDOM, 40, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("ERR-02", "Kernel_Windex driven out of range"); t.scenario = SCN_KERNEL_IDX_OOB;
    t.expect_data_check = 0;
    t.add_frame(PAT_RANDOM, 41, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("ERR-03", "read attempted while the FIFO is empty"); t.scenario = SCN_READ_WHEN_EMPTY;
    t.add_frame(PAT_RANDOM, 42, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("ERR-04", "output FIFO full / producer faster than consumer"); t.scenario = SCN_FIFO_FULL;
    t.expect_data_check = 0;
    t.add_frame(PAT_RANDOM, 43, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("ERR-05", "write asserted while Busy=1 (write during scan)"); t.scenario = SCN_WRITE_DURING_BUSY;
    t.expect_data_check = 0;
    t.add_frame(PAT_RANDOM, 44, KER_EDGE, 0, 0); tests.push_back(t);

    // ERR-06 / ERR-07 (AXI) run in axi_smoke_test.sv.

    // ---------------- TIMING / PROTOCOL ----------------
    t = new("TIM-01", "Start-to-Busy latency"); t.scenario = SCN_START_TO_BUSY;
    t.add_frame(PAT_RANDOM, 50, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("TIM-02", "Start-to-first-valid-output pipeline latency"); t.scenario = SCN_PIPE_LATENCY;
    t.add_frame(PAT_RANDOM, 51, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("TIM-03", "Raw_Valid gating exact boundary (small image)");
    t.img_w = 8; t.img_h = 8; t.k = 3;
    t.add_frame(PAT_RANDOM, 52, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("TIM-04", "Scan_Done single-cycle pulse");
    t.add_frame(PAT_RANDOM, 53, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("TIM-05", "address-stream count, no gaps/repeats");
    t.add_frame(PAT_RANDOM, 54, KER_EDGE, 0, 0); tests.push_back(t);

    t = new("TIM-06", "Out_Data/Out_Valid held stable while unread"); t.scenario = SCN_HOLD_NO_READ;
    t.add_frame(PAT_RANDOM, 55, KER_EDGE, 0, 0); tests.push_back(t);

    // TIM-07 (mac.v 2-cycle latency) runs in mac_unit_test.sv.
    // TIM-08 / TIM-09 (AXI handshakes) run in axi_smoke_test.sv.
  endfunction

endpackage

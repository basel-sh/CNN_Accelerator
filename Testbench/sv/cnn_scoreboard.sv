//==============================================================================
// cnn_scoreboard.sv | Class: cnn_scoreboard
// Compares driver-captured RTL output streams against cnn_pkg::golden_frame,
// tracks PASS/FAIL/OBSERVED per test-plan row, and hosts the scenario-level
// functional covergroup (kernel type, ReLU, image size, kernel size,
// scenario) that ties back to the "Coverage Goal (Functional)" column of
// Verification_Test_Plan.xlsx.
//==============================================================================
import cnn_pkg::*;

class cnn_scoreboard;
  int pass_cnt = 0, fail_cnt = 0, observed_cnt = 0;
  string fail_ids[$];

  covergroup cg_scenario with function sample(ker_pattern_e kt, bit relu_en, int img_area,
                                                int ksz, scenario_e scn);
    option.per_instance = 1;
    cp_kernel:    coverpoint kt;
    cp_relu:      coverpoint relu_en;
    cp_imgarea:   coverpoint img_area { bins min_32x32 = {1024}; bins larger = default; }
    cp_ksize:     coverpoint ksz      { bins k3 = {3}; bins k5 = {5}; bins other = default; }
    cp_scenario:  coverpoint scn;
    cx_kernel_relu: cross cp_kernel, cp_relu;
  endgroup

  function new();
    cg_scenario = new();
  endfunction

  // Bit-exact array compare (mirrors Python/verify.py's compare_outputs()).
  function void check_frame(string test_id, string desc, longint signed exp_arr[],
                             longint signed act_arr[], bit strict = 1);
    int mism, n;
    bit shape_ok;
    n = exp_arr.size();
    mism = 0;
    shape_ok = (act_arr.size() == n);
    if (!shape_ok) begin
      $display("[SB][%s] shape mismatch: expected %0d outputs, got %0d", test_id, n, act_arr.size());
      mism = n; // count every position as mismatched when shapes disagree
    end else begin
      for (int i = 0; i < n; i++)
        if (exp_arr[i] !== act_arr[i]) begin
          if (mism < 5)
            $display("[SB][%s]   mismatch @%0d: golden=%0d rtl=%0d", test_id, i, exp_arr[i], act_arr[i]);
          mism++;
        end
    end

    if (mism == 0) begin
      $display("[SB][%s] PASS - %0d outputs bit-exact vs the golden model (%s)", test_id, n, desc);
      pass_cnt++;
    end else if (strict) begin
      $display("[SB][%s] FAIL - %0d/%0d mismatches (%s)", test_id, mism, n, desc);
      fail_cnt++;
      fail_ids.push_back(test_id);
    end else begin
      $display("[SB][%s] OBSERVED - %0d/%0d differ vs golden (%s); documentation case, not scored as FAIL",
                test_id, mism, n, desc);
      observed_cnt++;
    end
  endfunction

  function void note_observed(string test_id, string msg);
    observed_cnt++;
    $display("[SB][%s] OBSERVED - %s", test_id, msg);
  endfunction

  function void note_pass(string test_id, string msg);
    pass_cnt++;
    $display("[SB][%s] PASS - %s", test_id, msg);
  endfunction

  function void note_fail(string test_id, string msg);
    fail_cnt++;
    fail_ids.push_back(test_id);
    $display("[SB][%s] FAIL - %s", test_id, msg);
  endfunction

  function void sample_scenario(cnn_txn t);
    foreach (t.frames[i])
      cg_scenario.sample(t.frames[i].ker_pat, t.frames[i].relu_en, t.img_w*t.img_h, t.k, t.scenario);
  endfunction

  function void print_summary();
    $display("=====================================================================");
    $display(" SCOREBOARD SUMMARY: PASS=%0d  FAIL=%0d  OBSERVED=%0d  (scenario functional coverage = %0.1f%%)",
              pass_cnt, fail_cnt, observed_cnt, cg_scenario.get_coverage());
    if (fail_cnt == 0) $display(" RESULT: ALL SCORED TESTS PASSED");
    else begin
      $display(" RESULT: %0d TEST(S) FAILED ->", fail_cnt);
      foreach (fail_ids[i]) $display("   - %s", fail_ids[i]);
    end
    $display("=====================================================================");
  endfunction
endclass

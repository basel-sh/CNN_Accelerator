#!/usr/bin/env python3
"""
run_all.py - single-command verification runner for CNN_Accelerator.

Compiles and simulates the entire RTL/ design (Icarus Verilog), compares
every result against the independent Python golden model, and writes the
real PASS/FAIL outcome for every row straight into Verification_Test_Plan.xlsx
(column H = Status). Nothing here is hand-typed - every Status cell this
script touches reflects an actual simulation run from this invocation.

Usage (from anywhere):
    python run_all.py

Requirements:
    - Icarus Verilog (iverilog / vvp) on PATH.
        Windows:  choco install icarus-verilog   (or the official installer)
        Linux:    sudo apt-get install iverilog
    - Python packages: numpy, openpyxl
        pip install numpy openpyxl

Two rows are intentionally NOT touched by this script and are left exactly
as they are in the sheet:
    - FUNC-02 : evidence is the original Vivado/XSim log, not reproducible
                without Vivado.
    - B2B-05  : a code-inspection fact (Img_W/Img_H are compile-time
                Verilog parameters), nothing to simulate at run-time.
"""
import os
import re
import sys
import json
import shutil
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent          # Testbench/audit_icarus_2026-09-12/
REPO_ROOT  = SCRIPT_DIR.parent.parent                  # CNN_Accelerator/
RTL        = REPO_ROOT / "RTL"
PYDIR      = REPO_ROOT / "Python"
XLSX       = REPO_ROOT / "Verification_Test_Plan.xlsx"
MEM        = SCRIPT_DIR / "mem"
SIM        = SCRIPT_DIR / "sim"

sys.path.insert(0, str(PYDIR))
os.chdir(SCRIPT_DIR)
MEM.mkdir(exist_ok=True)
SIM.mkdir(exist_ok=True)

try:
    import numpy as np
except ImportError:
    sys.exit("Missing dependency: numpy. Run:  pip install numpy openpyxl")
try:
    import openpyxl
    from openpyxl.styles import PatternFill
except ImportError:
    sys.exit("Missing dependency: openpyxl. Run:  pip install numpy openpyxl")

if shutil.which("iverilog") is None or shutil.which("vvp") is None:
    sys.exit(
        "iverilog/vvp not found on PATH.\n"
        "Windows:  choco install icarus-verilog  (or http://bleyer.org/icarus/)\n"
        "Linux:    sudo apt-get install iverilog\n"
        "Then re-run this script."
    )

from image_generator import generate_test_image, generate_test_kernel
from golden_model import run_golden_model
from utilities import quantize_signed, quantize_unsigned, to_twos_complement_hex, from_twos_complement

RESULTS = {}   # Test ID -> True (all evidence for it passed) / False


def log(msg):
    print(msg, flush=True)


# ---------------------------------------------------------------------------
# helpers shared by every stage
# ---------------------------------------------------------------------------
def write_mem(arr, path, width, signed):
    flat = np.asarray(arr).flatten()
    with open(path, "w") as f:
        for v in flat:
            if signed:
                v = int(quantize_signed(np.array([v]), width)[0])
                f.write(to_twos_complement_hex(v, width) + "\n")
            else:
                v = int(quantize_unsigned(np.array([v]), width)[0])
                f.write(format(v, "0{}x".format((width + 3) // 4)) + "\n")


def read_mem(path, shape, width, signed):
    vals = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            vals.append(from_twos_complement(line, width) if signed else int(line, 16))
    return np.array(vals, dtype=np.int64).reshape(shape)


def clog2(n):
    return max(1, (n - 1).bit_length())


def merge(test_id, ok):
    """AND a new pass/fail observation into RESULTS[test_id]."""
    RESULTS[test_id] = ok if test_id not in RESULTS else (RESULTS[test_id] and ok)


CHECK_RE = re.compile(r"^CHECK (PASS|FAIL): ([^\r\n]*)$")
ID_RE = re.compile(r"\b([A-Z][A-Z0-9]{2,4}-\d{2})\b")  # matches FUNC-01, BND-01, B2B-01, ...


def run_and_scrape_checks(vvp_path):
    """Run a compiled .vvp, scrape 'CHECK PASS/FAIL: <ID>[/<ID2>]: ...' lines,
    and merge a pass/fail verdict into RESULTS for every Test ID mentioned."""
    r = subprocess.run(["vvp", str(vvp_path)], capture_output=True, text=True, timeout=120)
    out = r.stdout + r.stderr
    n_checks = 0
    for line in out.splitlines():
        m = CHECK_RE.match(line.strip())
        if not m:
            continue
        n_checks += 1
        passed = (m.group(1) == "PASS")
        for tid in ID_RE.findall(m.group(2)):
            merge(tid, passed)
    return out, n_checks


def compile_tb(name, sources, extra_params=None):
    vvp_out = SIM / f"{name}.vvp"
    cmd = ["iverilog", "-g2012", "-o", str(vvp_out)]
    if extra_params:
        cmd += extra_params
    cmd += [str(s) for s in sources]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        log(f"  COMPILE FAILED ({name}):\n{r.stderr[:3000]}")
        return None
    return vvp_out


RTL_CORE = [RTL / f for f in (
    "top_2px.v", "controller_2px.v", "image_memory_2px.v", "kernel_memory.v",
    "line_buffer_2px.v", "window_generator_2px.v", "mac_pair.v", "fifo_pair.v",
)]


# ---------------------------------------------------------------------------
# Stage 1: direct unit-level testbenches (check()-based, ID-labeled)
# ---------------------------------------------------------------------------
def stage_unit_tests():
    log("\n=== Stage 1/4: unit-level testbenches ===")
    jobs = [
        ("tb_mac_unit", [SCRIPT_DIR / "tb_mac_unit.v", RTL / "mac_pair.v"]),
        ("tb_ctrl_unit", [SCRIPT_DIR / "tb_ctrl_unit.v", RTL / "controller_2px.v"]),
        ("tb_kernel_unit", [SCRIPT_DIR / "tb_kernel_unit.v", RTL / "kernel_memory.v"]),
        ("tb_imgmem_unit", [SCRIPT_DIR / "tb_imgmem_unit.v", RTL / "image_memory_2px.v"]),
    ]
    for name, sources in jobs:
        vvp = compile_tb(name, sources)
        if vvp is None:
            continue
        out, n = run_and_scrape_checks(vvp)
        summary = next((l for l in out.splitlines() if l.startswith("TB_")), "")
        log(f"  {name}: {summary}  ({n} checks scraped)")


# ---------------------------------------------------------------------------
# Stage 2: AXI-Lite + backpressure/FIFO testbenches (check()-based, top_2px)
# ---------------------------------------------------------------------------
def stage_top_level_check_tests():
    log("\n=== Stage 2/4: FIFO backpressure + AXI-Lite testbenches ===")
    # both need the same 8x8/K=3 stimulus used by the original audit
    img_bp = generate_test_image(8, 8, "random", 505, 8)
    k_bp = generate_test_kernel(3, "box_blur", 8)
    write_mem(img_bp, MEM / "bp_image.mem", 8, False)
    write_mem(k_bp, MEM / "bp_kernel.mem", 8, True)

    jobs = [
        ("tb_backpressure", [SCRIPT_DIR / "tb_backpressure.v"] + RTL_CORE),
        ("tb_axi_lite", [SCRIPT_DIR / "tb_axi_lite.v", RTL / "axi_lite_top_2px.v"] + RTL_CORE),
    ]
    for name, sources in jobs:
        vvp = compile_tb(name, sources)
        if vvp is None:
            continue
        out, n = run_and_scrape_checks(vvp)
        summary = next((l for l in out.splitlines() if l.startswith("TB_")), "")
        log(f"  {name}: {summary}  ({n} checks scraped)")

    # RST-03 also requires the post-reset clean-run frame to be bit-exact,
    # not just the check()-based assertions above - compared in stage 3.


# ---------------------------------------------------------------------------
# Stage 3: golden-model comparisons (generic top-level harness + scenarios)
# ---------------------------------------------------------------------------
def run_generic(test_id, image, kernel, relu=False, img_w=None, img_h=None, k=None,
                 pixel_w=8, kernel_w=8, acc_w=20):
    img_h_, img_w_ = image.shape
    k_ = kernel.shape[0]
    img_w, img_h, k = img_w or img_w_, img_h or img_h_, k or k_
    addrw, kidxw = clog2(img_w * img_h), clog2(k * k)
    write_mem(image, MEM / "image.mem", pixel_w, False)
    write_mem(kernel, MEM / "kernel.mem", kernel_w, True)

    vvp_out = SIM / f"{test_id}.vvp"
    r = subprocess.run([
        "iverilog", "-g2012", "-o", str(vvp_out),
        f"-Ptb_generic.Pixel_W={pixel_w}", f"-Ptb_generic.Kernel_W={kernel_w}",
        f"-Ptb_generic.Acc_W={acc_w}", f"-Ptb_generic.Img_W={img_w}",
        f"-Ptb_generic.Img_H={img_h}", f"-Ptb_generic.K={k}",
        f"-Ptb_generic.Img_Addrw={addrw}", f"-Ptb_generic.Kidxw={kidxw}",
        f"-Ptb_generic.RELU={1 if relu else 0}",
        str(SCRIPT_DIR / "tb_generic.v"), *[str(s) for s in RTL_CORE],
    ], capture_output=True, text=True)
    if r.returncode != 0:
        log(f"  COMPILE FAILED ({test_id}):\n{r.stderr[:2000]}")
        return False

    subprocess.run(["vvp", str(vvp_out)], capture_output=True, text=True, timeout=120)
    out_h, out_w = img_h - k + 1, img_w - k + 1
    try:
        rtl_out = read_mem(SIM / "rtl_output.mem", (out_h, out_w), acc_w, True)
    except Exception as e:
        log(f"  {test_id}: could not read RTL output ({e})")
        return False
    golden = run_golden_model(image, kernel, Apply_Relu=relu, Pixel_Width=pixel_w,
                               Kernel_Width=kernel_w, Acc_Width=acc_w)
    mism = int(np.count_nonzero(np.abs(golden.astype(np.int64) - rtl_out.astype(np.int64))))
    ok = mism == 0
    log(f"  {test_id}: {golden.size} outputs, {mism} mismatches -> {'PASS' if ok else 'FAIL'}")
    return ok


def compare_frame(name, rtl_mem_path, image, kernel, relu=False):
    out_h, out_w = image.shape[0] - kernel.shape[0] + 1, image.shape[1] - kernel.shape[1] + 1
    rtl = read_mem(rtl_mem_path, (out_h, out_w), 20, True)
    golden = run_golden_model(image, kernel, Apply_Relu=relu)
    mism = int(np.count_nonzero(np.abs(golden.astype(np.int64) - rtl.astype(np.int64))))
    ok = mism == 0
    log(f"  {name}: {golden.size} outputs, {mism} mismatches -> {'PASS' if ok else 'FAIL'}")
    return ok


def stage_golden_comparisons():
    log("\n=== Stage 3/4: golden-model bit-exact comparisons ===")

    # --- generic single-frame rows (FUNC-01/03/05/06/07, most BND-xx) ---
    real_img_path = SCRIPT_DIR / "real_input_32x32.mem"
    if real_img_path.exists():
        real_img = read_mem(real_img_path, (32, 32), 8, False)
    else:
        real_img = generate_test_image(32, 32, "random", 9001, 8)  # fallback if not shipped

    merge("FUNC-01", run_generic("FUNC-01", real_img, generate_test_kernel(3, "identity")))
    k_edge = np.array([[-1, -1, -1], [-1, 8, -1], [-1, -1, -1]])
    merge("FUNC-03", run_generic("FUNC-03", real_img, k_edge, relu=True))

    f05_ok = True
    for seed in range(10):
        img = generate_test_image(32, 32, "random", seed, 8)
        ker = generate_test_kernel(3, "random", 8)
        f05_ok &= run_generic(f"FUNC-05-seed{seed}", img, ker, relu=(seed % 2 == 0))
    merge("FUNC-05", f05_ok)

    merge("FUNC-06", run_generic("FUNC-06", generate_test_image(64, 64, "random", 42, 8),
                                  generate_test_kernel(3, "random", 8), img_w=64, img_h=64, k=3))
    merge("FUNC-07", run_generic("FUNC-07", generate_test_image(32, 32, "random", 43, 8),
                                  generate_test_kernel(5, "random", 8), img_w=32, img_h=32, k=5))

    merge("BND-01", run_generic("BND-01", generate_test_image(32, 32, "random", 100, 8),
                                 generate_test_kernel(3, "random", 8)))
    merge("BND-02", run_generic("BND-02", generate_test_image(64, 64, "random", 101, 8),
                                 generate_test_kernel(3, "random", 8), img_w=64, img_h=64, k=3))
    merge("BND-03", run_generic("BND-03", generate_test_image(32, 32, "zeros", 0, 8),
                                 generate_test_kernel(3, "random", 8)))
    merge("BND-04", run_generic("BND-04", generate_test_image(32, 32, "max", 0, 8),
                                 generate_test_kernel(3, "random", 8)))
    merge("BND-05", run_generic("BND-05", generate_test_image(32, 32, "checkerboard", 0, 8), k_edge))
    merge("BND-06", run_generic("BND-06", generate_test_image(32, 32, "random", 102, 8),
                                 np.zeros((3, 3), dtype=np.int64)))
    merge("BND-09", run_generic("BND-09", np.full((32, 32), 77, dtype=np.int64), k_edge, relu=True))
    img_ca = np.zeros((32, 32), dtype=np.int64); img_ca[0, 0] = 200
    img_cb = np.zeros((32, 32), dtype=np.int64); img_cb[31, 31] = 200
    k_box = generate_test_kernel(3, "box_blur", 8)
    merge("BND-10", run_generic("BND-10a", img_ca, k_box) and run_generic("BND-10b", img_cb, k_box))

    # --- multi-phase scenario rows: generate stimulus, run the scenario
    #     testbenches, then compare each captured frame to the golden model ---
    def gen(seed, h=8, w=8, kind="random"):
        return generate_test_image(w, h, kind, seed, 8)

    img_rl = gen(500); kA = generate_test_kernel(3, "identity"); kB = generate_test_kernel(3, "random")
    write_mem(img_rl, MEM / "reload_image.mem", 8, False)
    write_mem(kA, MEM / "reload_kernelA.mem", 8, True)
    write_mem(kB, MEM / "reload_kernelB.mem", 8, True)

    img1, img2 = gen(501), gen(502)
    kx = generate_test_kernel(3, "sharpen")
    write_mem(img1, MEM / "rst04_image1.mem", 8, False)
    write_mem(img2, MEM / "rst04_image2.mem", 8, False)
    write_mem(kx, MEM / "rst04_kernel.mem", 8, True)

    img_b, k_b = gen(503), generate_test_kernel(3, "edge")
    write_mem(img_b, MEM / "b2b04_image.mem", 8, False)
    write_mem(k_b, MEM / "b2b04_kernel.mem", 8, True)

    img_t, k_t = gen(504), generate_test_kernel(3, "edge")
    write_mem(img_t, MEM / "tim02_image.mem", 8, False)
    write_mem(k_t, MEM / "tim02_kernel.mem", 8, True)

    for name, sources in [
        ("tb_reload_switch", [SCRIPT_DIR / "tb_reload_switch.v"] + RTL_CORE),
        ("tb_rst04", [SCRIPT_DIR / "tb_rst04.v"] + RTL_CORE),
        ("tb_b2b04", [SCRIPT_DIR / "tb_b2b04.v"] + RTL_CORE),
        ("tb_tim02", [SCRIPT_DIR / "tb_tim02.v"] + RTL_CORE),
    ]:
        vvp = compile_tb(name, sources)
        if vvp is None:
            continue
        r = subprocess.run(["vvp", str(vvp)], capture_output=True, text=True, timeout=120)
        for l in (r.stdout + r.stderr).splitlines():
            if l.strip():
                log(f"    [{name}] {l.strip()}")

    ok = compare_frame("FUNC-04/B2B-03 run1", SIM / "reload_run1.mem", img_rl, kA)
    ok &= compare_frame("FUNC-04/B2B-03 run2", SIM / "reload_run2.mem", img_rl, kB)
    merge("FUNC-04", ok); merge("B2B-03", ok)

    ok = compare_frame("RST-04 run1", SIM / "rst04_run1.mem", img1, kx)
    ok &= compare_frame("RST-04 run2", SIM / "rst04_run2.mem", img2, kx)
    merge("RST-04", ok)

    ok = compare_frame("B2B-04 frame0", SIM / "b2b04_run0.mem", img_b, k_b)
    ok &= compare_frame("B2B-04 frame1", SIM / "b2b04_run1.mem", img_b, k_b)
    ok &= compare_frame("B2B-04 frame2", SIM / "b2b04_run2.mem", img_b, k_b)
    merge("B2B-04", ok)

    merge("TIM-02", compare_frame("TIM-02 value check", SIM / "tim02_out.mem", img_t, k_t))

    # RST-03's clean-run frame (Out_Rd_En=1, post reset, produced by tb_backpressure
    # in stage 2 using mem/bp_image.mem + mem/bp_kernel.mem written in stage 2)
    bp_img = read_mem(MEM / "bp_image.mem", (8, 8), 8, False)
    bp_ker = read_mem(MEM / "bp_kernel.mem", (3, 3), 8, True)
    merge("RST-03", compare_frame("RST-03 post-reset clean run", SIM / "bp_clean_run.mem", bp_img, bp_ker))


# ---------------------------------------------------------------------------
# Stage 4: write results into the xlsx
# ---------------------------------------------------------------------------
def stage_write_xlsx():
    log("\n=== Stage 4/4: writing results into Verification_Test_Plan.xlsx ===")
    if not XLSX.exists():
        log(f"  xlsx not found at {XLSX}, skipping write.")
        return
    wb = openpyxl.load_workbook(XLSX)
    ws = wb["Verification Test Plan"]
    fill_pass = PatternFill("solid", fgColor="C6EFCE")
    fill_fail = PatternFill("solid", fgColor="FFC7CE")

    touched, untouched = 0, []
    for row in range(3, 49):
        tid = ws.cell(row=row, column=1).value
        if not tid:
            continue
        if tid not in RESULTS:
            untouched.append(tid)
            continue
        ok = RESULTS[tid]
        old_status = ws.cell(row=row, column=8).value
        new_status = "Passed" if ok else "Failed"
        # preserve a trailing '*' annotation already on the cell (documents a
        # known caveat, e.g. TIM-03's reworded formula) rather than clobbering it
        if old_status and old_status.rstrip().endswith("*") and ok:
            new_status = "Passed*"
        ws.cell(row=row, column=8, value=new_status)
        ws.cell(row=row, column=8).fill = fill_pass if ok else fill_fail
        touched += 1

    ws2 = wb["Summary"]
    counts = {"Passed": 0, "Passed*": 0, "Failed": 0, "Blocked": 0, "Not Run": 0}
    for row in range(3, 49):
        tid = ws.cell(row=row, column=1).value
        if not tid:
            continue
        st = ws.cell(row=row, column=8).value or "Not Run"
        counts[st] = counts.get(st, 0) + 1
    ws2.cell(row=3, column=7, value="Passed"); ws2.cell(row=3, column=8, value=counts["Passed"] + counts["Passed*"])
    ws2.cell(row=4, column=7, value="Not Run"); ws2.cell(row=4, column=8, value=counts["Not Run"])
    ws2.cell(row=5, column=7, value="Failed"); ws2.cell(row=5, column=8, value=counts["Failed"])
    ws2.cell(row=6, column=7, value="Blocked (no RTL to test)"); ws2.cell(row=6, column=8, value=counts["Blocked"])

    wb.save(XLSX)
    log(f"  updated {touched} rows, saved {XLSX.name}")
    if untouched:
        log(f"  left unchanged (not derivable by this script): {', '.join(untouched)}")
    log(f"  final counts: {counts}")


def main():
    log(f"Repo root: {REPO_ROOT}")
    log(f"xlsx:      {XLSX}")
    stage_unit_tests()
    stage_top_level_check_tests()
    stage_golden_comparisons()
    stage_write_xlsx()

    fails = sorted(tid for tid, ok in RESULTS.items() if not ok)
    log("\n=== DONE ===")
    if fails:
        log(f"FAILING: {', '.join(fails)}")
        sys.exit(1)
    log(f"All {len(RESULTS)} simulated rows PASS.")


if __name__ == "__main__":
    main()

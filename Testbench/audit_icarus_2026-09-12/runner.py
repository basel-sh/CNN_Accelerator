import sys, os, subprocess, math, json
sys.path.insert(0, "Python")
import numpy as np
from image_generator import generate_test_image, generate_test_kernel
from golden_model import run_golden_model
from utilities import quantize_signed, quantize_unsigned, to_twos_complement_hex, from_twos_complement

RESULTS = {}

def write_mem(arr, path, width, signed):
    flat = np.asarray(arr).flatten()
    with open(path, "w") as f:
        for v in flat:
            if signed:
                v = int(quantize_signed(np.array([v]), width)[0])
                f.write(to_twos_complement_hex(v, width) + "\n")
            else:
                v = int(quantize_unsigned(np.array([v]), width)[0])
                f.write(format(v, "0{}x".format((width+3)//4)) + "\n")

def read_mem(path, shape, width, signed):
    vals = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            if signed:
                vals.append(from_twos_complement(line, width))
            else:
                vals.append(int(line, 16))
    return np.array(vals, dtype=np.int64).reshape(shape)

def clog2(n):
    return max(1, (n-1).bit_length())

def run_generic(test_id, image, kernel, relu=False, img_w=None, img_h=None, k=None,
                 pixel_w=8, kernel_w=8, acc_w=20, expect_fail_reason=None):
    img_h_, img_w_ = image.shape
    k_ = kernel.shape[0]
    img_w = img_w or img_w_
    img_h = img_h or img_h_
    k = k or k_
    addrw = clog2(img_w*img_h)
    kidxw = clog2(k*k)
    write_mem(image, "mem/image.mem", pixel_w, False)
    write_mem(kernel, "mem/kernel.mem", kernel_w, True)

    vvp_out = f"sim/{test_id}.vvp"
    compile_cmd = [
        "iverilog", "-g2012", "-o", vvp_out,
        "-Ptb_generic.Pixel_W=%d" % pixel_w,
        "-Ptb_generic.Kernel_W=%d" % kernel_w,
        "-Ptb_generic.Acc_W=%d" % acc_w,
        "-Ptb_generic.Img_W=%d" % img_w,
        "-Ptb_generic.Img_H=%d" % img_h,
        "-Ptb_generic.K=%d" % k,
        "-Ptb_generic.Img_Addrw=%d" % addrw,
        "-Ptb_generic.Kidxw=%d" % kidxw,
        "-Ptb_generic.RELU=%d" % (1 if relu else 0),
        "tb/tb_generic.v", "RTL/top_2px.v", "RTL/controller_2px.v",
        "RTL/image_memory_2px.v", "RTL/kernel_memory.v", "RTL/line_buffer_2px.v",
        "RTL/window_generator_2px.v", "RTL/mac_pair.v", "RTL/fifo_pair.v",
    ]
    r = subprocess.run(compile_cmd, capture_output=True, text=True)
    if r.returncode != 0:
        RESULTS[test_id] = {"status": "FAIL", "reason": "compile error: " + r.stderr[:2000]}
        return RESULTS[test_id]

    r2 = subprocess.run(["vvp", vvp_out], capture_output=True, text=True, timeout=120)
    sim_log = r2.stdout + r2.stderr

    out_h, out_w = img_h - k + 1, img_w - k + 1
    try:
        rtl_out = read_mem("sim/rtl_output.mem", (out_h, out_w), acc_w, True)
    except Exception as e:
        RESULTS[test_id] = {"status": "FAIL", "reason": f"could not read rtl output: {e}", "sim_log": sim_log[-1500:]}
        return RESULTS[test_id]

    golden = run_golden_model(image, kernel, Apply_Relu=relu, Pixel_Width=pixel_w,
                               Kernel_Width=kernel_w, Acc_Width=acc_w)
    diff = np.abs(golden.astype(np.int64) - rtl_out.astype(np.int64))
    mism = int(np.count_nonzero(diff))
    total = int(golden.size)
    status = "PASS" if mism == 0 else "FAIL"
    RESULTS[test_id] = {
        "status": status, "total": total, "mismatches": mism,
        "max_abs_diff": int(diff.max()) if diff.size else 0,
        "sim_log_tail": sim_log.strip().splitlines()[-4:],
    }
    return RESULTS[test_id]

def save():
    with open("results.json", "w") as f:
        json.dump(RESULTS, f, indent=2)

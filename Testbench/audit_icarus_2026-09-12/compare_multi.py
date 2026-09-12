import sys, json
sys.path.insert(0, "Python")
import numpy as np
from golden_model import run_golden_model
from utilities import from_twos_complement, quantize_unsigned

def read_mem_raw(path, signed, width):
    vals = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            if signed:
                vals.append(from_twos_complement(line, width))
            else:
                vals.append(int(line, 16))
    return np.array(vals, dtype=np.int64)

def read_img_kernel(img_path, k_path, h, w, k):
    img = read_mem_raw(img_path, False, 8).reshape(h, w)
    ker = read_mem_raw(k_path, True, 8).reshape(k, k)
    return img, ker

def compare(name, rtl_path, image, kernel, relu=False):
    out_h, out_w = image.shape[0]-kernel.shape[0]+1, image.shape[1]-kernel.shape[1]+1
    rtl = read_mem_raw(rtl_path, True, 20).reshape(out_h, out_w)
    golden = run_golden_model(image, kernel, Apply_Relu=relu)
    diff = np.abs(golden.astype(np.int64) - rtl.astype(np.int64))
    mism = int(np.count_nonzero(diff))
    print(f"{name}: total={golden.size} mismatches={mism} max_abs_diff={int(diff.max()) if diff.size else 0} -> {'PASS' if mism==0 else 'FAIL'}")
    return mism == 0

img, kA = read_img_kernel("mem/reload_image.mem", "mem/reload_kernelA.mem", 8, 8, 3)
_, kB = read_img_kernel("mem/reload_image.mem", "mem/reload_kernelB.mem", 8, 8, 3)
r1 = compare("FUNC-04/B2B-03 RUN1 (kernel A)", "sim/reload_run1.mem", img, kA)
r2 = compare("FUNC-04/B2B-03 RUN2 (kernel B, no reset)", "sim/reload_run2.mem", img, kB)

img1, kx = read_img_kernel("mem/rst04_image1.mem", "mem/rst04_kernel.mem", 8, 8, 3)
img2, _  = read_img_kernel("mem/rst04_image2.mem", "mem/rst04_kernel.mem", 8, 8, 3)
r3 = compare("RST-04 RUN1", "sim/rst04_run1.mem", img1, kx)
r4 = compare("RST-04 RUN2 (post 2nd reset, different image)", "sim/rst04_run2.mem", img2, kx)

imgb, kb = read_img_kernel("mem/b2b04_image.mem", "mem/b2b04_kernel.mem", 8, 8, 3)
r5 = compare("B2B-04 frame0", "sim/b2b04_run0.mem", imgb, kb)
r6 = compare("B2B-04 frame1", "sim/b2b04_run1.mem", imgb, kb)
r7 = compare("B2B-04 frame2", "sim/b2b04_run2.mem", imgb, kb)

imgt, kt = read_img_kernel("mem/tim02_image.mem", "mem/tim02_kernel.mem", 8, 8, 3)
r8 = compare("TIM-02 first/whole-array value check", "sim/tim02_out.mem", imgt, kt)

imgbp, kbp = read_img_kernel("mem/bp_image.mem", "mem/bp_kernel.mem", 8, 8, 3)
r9 = compare("RST-03 post-reset clean run", "sim/bp_clean_run.mem", imgbp, kbp)

print(json.dumps({
    "FUNC-04": r1 and r2, "B2B-03": r1 and r2,
    "RST-04": r3 and r4,
    "B2B-04": r5 and r6 and r7,
    "TIM-02_value_check": r8,
    "RST-03_clean_run_check": r9,
}))

"""
File     : verify.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 9 - Simulation / Verification

Automatic PASS/FAIL comparison: recomputes the golden-model expected output
for a given image/kernel pair and compares it element-by-element against the
RTL simulation's captured output (a $readmemh-style hex file, two's
complement, written by Testbench/tb_top.v).

Usage:
    python Python/verify.py \\
        --image Images/input_image.mem \\
        --kernel Images/kernels/edge_3x3.mem \\
        --rtl-output sim/rtl_output.mem \\
        --img-size 32 32 --k 3 \\
        --pixel-width 8 --kernel-width 8 --acc-width 20 [--relu]

Exit code 0 = PASS, 1 = FAIL, matching standard CI conventions.
"""

import argparse
import sys
import numpy as np

from image_loader import read_mem_file
from golden_model import run_golden_model


def compare_outputs(golden, rtl_output, tolerance=0):
    """Element-wise PASS/FAIL comparison. Returns (passed, mismatch_info)."""
    golden = np.asarray(golden)
    rtl_output = np.asarray(rtl_output)

    if golden.shape != rtl_output.shape:
        return False, {"error": f"shape mismatch: golden={golden.shape} rtl={rtl_output.shape}"}

    diff = np.abs(golden.astype(np.int64) - rtl_output.astype(np.int64))
    mismatches = np.argwhere(diff > tolerance)

    info = {
        "total": golden.size,
        "mismatches": len(mismatches),
        "max_abs_diff": int(diff.max()) if diff.size else 0,
        "first_mismatches": [
            {"pos": tuple(int(x) for x in pos),
             "golden": int(golden[tuple(pos)]),
             "rtl": int(rtl_output[tuple(pos)])}
            for pos in mismatches[:10]
        ],
    }
    return len(mismatches) == 0, info


def main():
    ap = argparse.ArgumentParser(description="Compare RTL simulation output to the Python golden model.")
    ap.add_argument("--image", required=True)
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--rtl-output", required=True)
    ap.add_argument("--img-size", nargs=2, type=int, default=[32, 32], metavar=("H", "W"))
    ap.add_argument("--k", type=int, default=3)
    ap.add_argument("--pixel-width", type=int, default=8)
    ap.add_argument("--kernel-width", type=int, default=8)
    ap.add_argument("--acc-width", type=int, default=20)
    ap.add_argument("--relu", action="store_true")
    args = ap.parse_args()

    img_h, img_w = args.img_size
    out_h, out_w = img_h - args.k + 1, img_w - args.k + 1

    image = read_mem_file(args.image, (img_h, img_w), args.pixel_width, signed=False)
    kernel = read_mem_file(args.kernel, (args.k, args.k), args.kernel_width, signed=True)
    golden = run_golden_model(image, kernel, apply_relu=args.relu,
                               pixel_width=args.pixel_width,
                               kernel_width=args.kernel_width,
                               acc_width=args.acc_width)

    rtl_output = read_mem_file(args.rtl_output, (out_h, out_w), args.acc_width, signed=True)

    passed, info = compare_outputs(golden, rtl_output)

    print(f"Compared {info.get('total', 0)} output values.")
    if passed:
        print("RESULT: PASS - RTL output matches the golden model exactly.")
    else:
        print(f"RESULT: FAIL - {info.get('mismatches', '?')} mismatch(es), "
              f"max abs diff = {info.get('max_abs_diff', '?')}")
        for m in info.get("first_mismatches", []):
            print(f"  pos={m['pos']} golden={m['golden']} rtl={m['rtl']}")

    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()

"""
File    : verify.py
Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Automatic PASS/FAIL: recomputes the golden-model expected output for a given
image/kernel pair and compares it element-by-element against the RTL
simulation's captured output (a $readmemh-style hex file, two's complement,
written by Testbench/tb_top.v).

Usage:
    python Python/verify.py \\
        --image Images/input_32x32.mem \\
        --kernel Images/kernels/edge_3x3.mem \\
        --rtl-output sim/rtl_output.mem \\
        --img-size 32 32 --k 3 \\
        --pixel-width 8 --kernel-width 8 --acc-width 20 [--relu]

Exit code 0 = PASS, 1 = FAIL (standard CI convention).
"""

import argparse
import sys
import numpy as np

from image_loader import read_mem_file
from golden_model import run_golden_model


def compare_outputs(Golden, Rtl_Output, Tolerance=0):
    """Element-wise PASS/FAIL comparison. Returns (Passed, Mismatch_Info)."""
    Golden = np.asarray(Golden)
    Rtl_Output = np.asarray(Rtl_Output)

    if Golden.shape != Rtl_Output.shape:
        return False, {"error": f"shape mismatch: golden={Golden.shape} rtl={Rtl_Output.shape}"}

    Diff = np.abs(Golden.astype(np.int64) - Rtl_Output.astype(np.int64))
    Mismatches = np.argwhere(Diff > Tolerance)

    Info = {
        "total": Golden.size,
        "mismatches": len(Mismatches),
        "max_abs_diff": int(Diff.max()) if Diff.size else 0,
        "first_mismatches": [
            {"pos": tuple(int(x) for x in Pos),
             "golden": int(Golden[tuple(Pos)]),
             "rtl": int(Rtl_Output[tuple(Pos)])}
            for Pos in Mismatches[:10]
        ],
    }
    return len(Mismatches) == 0, Info


def main():
    Ap = argparse.ArgumentParser(description="Compare RTL simulation output to the Python golden model.")
    Ap.add_argument("--image", required=True)
    Ap.add_argument("--kernel", required=True)
    Ap.add_argument("--rtl-output", required=True)
    Ap.add_argument("--img-size", nargs=2, type=int, default=[32, 32], metavar=("H", "W"))
    Ap.add_argument("--k", type=int, default=3)
    Ap.add_argument("--pixel-width", type=int, default=8)
    Ap.add_argument("--kernel-width", type=int, default=8)
    Ap.add_argument("--acc-width", type=int, default=20)
    Ap.add_argument("--relu", action="store_true")
    Args = Ap.parse_args()

    Img_H, Img_W = Args.img_size
    Out_H, Out_W = Img_H - Args.k + 1, Img_W - Args.k + 1

    Image = read_mem_file(Args.image, (Img_H, Img_W), Args.pixel_width, Signed=False)
    Kernel = read_mem_file(Args.kernel, (Args.k, Args.k), Args.kernel_width, Signed=True)
    Golden = run_golden_model(Image, Kernel, Apply_Relu=Args.relu,
                               Pixel_Width=Args.pixel_width,
                               Kernel_Width=Args.kernel_width,
                               Acc_Width=Args.acc_width)

    Rtl_Output = read_mem_file(Args.rtl_output, (Out_H, Out_W), Args.acc_width, Signed=True)

    Passed, Info = compare_outputs(Golden, Rtl_Output)

    print(f"Compared {Info.get('total', 0)} output values.")
    if Passed:
        print("RESULT: PASS - RTL output matches the golden model exactly.")
    else:
        print(f"RESULT: FAIL - {Info.get('mismatches', '?')} mismatch(es), "
              f"max abs diff = {Info.get('max_abs_diff', '?')}")
        for M in Info.get("first_mismatches", []):
            print(f"  pos={M['pos']} golden={M['golden']} rtl={M['rtl']}")

    sys.exit(0 if Passed else 1)


if __name__ == "__main__":
    main()

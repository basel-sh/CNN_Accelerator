"""
File     : mem_to_image.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Phase 3: turn the RTL's captured output back into a viewable PNG, for a
side-by-side comparison against Images/input_32x32_preview.png.

Note: a 3x3 "valid" convolution over a 32x32 image produces a 30x30 output
(border pixels are dropped - there's no way to center a 3x3 window on the
outermost ring of pixels). That's expected, not a bug.

Reads sim/rtl_output.mem (30x30, signed 20-bit, written by Testbench/tb_top.v
during the Vivado simulation) and writes Images/rtl_output_preview.png.

Usage:
    python Python/mem_to_image.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cv2
import numpy as np

from image_loader import read_mem_file

IMG_SIZE, K, ACC_W = 32, 3, 20
OUT_SIZE = IMG_SIZE - K + 1  # 30

out = read_mem_file("sim/rtl_output.mem", (OUT_SIZE, OUT_SIZE), ACC_W, signed=True)
mag = np.abs(out)
norm = (255 * mag / max(1, mag.max())).astype(np.uint8)
preview = cv2.resize(norm, (OUT_SIZE * 8, OUT_SIZE * 8), interpolation=cv2.INTER_NEAREST)
cv2.imwrite("Images/rtl_output_preview.png", preview)

print(f"Read sim/rtl_output.mem ({OUT_SIZE}x{OUT_SIZE}, signed {ACC_W}-bit)")
print("Wrote Images/rtl_output_preview.png")

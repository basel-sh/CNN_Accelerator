"""
File    : mem_to_image.py
Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Step 3 of the run flow: turns the RTL's captured output back into a viewable
PNG, for a side-by-side comparison against Images/input_32x32_preview.png.

Note: a 3x3 "valid" convolution over a 32x32 image produces a 30x30 output
(border pixels are dropped - expected, not a bug).

Reads sim/rtl_output.mem (30x30, signed 20-bit, written by Testbench/tb_top.v
during simulation) and writes Images/rtl_output_preview.png.

Usage:
    python Python/mem_to_image.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cv2
import numpy as np

from image_loader import read_mem_file

Img_Size, K, Acc_W = 32, 3, 16
Out_Size = Img_Size - K + 1  # 30

Out = read_mem_file("sim/rtl_output.mem", (Out_Size, Out_Size), Acc_W, Signed=True)
Mag = np.abs(Out)
Norm = (255 * Mag / max(1, Mag.max())).astype(np.uint8)
Preview = cv2.resize(Norm, (Out_Size * 8, Out_Size * 8), interpolation=cv2.INTER_NEAREST)
cv2.imwrite("Images/rtl_output_preview.png", Preview)

print(f"Read sim/rtl_output.mem ({Out_Size}x{Out_Size}, signed {Acc_W}-bit)")
print("Wrote Images/rtl_output_preview.png")

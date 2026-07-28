"""
File     : prepare_stimulus.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Phase 1 (Python-only): convert Images/input.png into RTL stimulus.

Loads Images/input.png, resizes+quantizes it to the RTL's IMG_W x IMG_H
(32x32, 8-bit unsigned - matches Testbench/tb_top.v's localparams), and
writes a vertical-edge-detection kernel (Sobel X, so vertical lines in the
photo light up strongly and horizontal lines mostly don't).

Writes:
  Images/input_image.mem          <- read by image_memory  (RTL, via tb_top.v)
  Images/kernels/edge_3x3.mem     <- read by kernel_memory (RTL, via tb_top.v)
  Images/input_32x32_preview.png  <- what the RTL will actually "see", viewable

Usage:
    python Python/prepare_stimulus.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cv2
import numpy as np

from image_loader import load_image, write_mem_file

PIXEL_W, KERNEL_W, IMG_SIZE = 8, 8, 32

quant_img = load_image("Images/input.png", size=(IMG_SIZE, IMG_SIZE), pixel_width=PIXEL_W)
write_mem_file(quant_img, "Images/input_image.mem", PIXEL_W, signed=False)

sobel_vertical = np.array([[-1, 0, 1],
                            [-2, 0, 2],
                            [-1, 0, 1]], dtype=np.int64)
write_mem_file(sobel_vertical, "Images/kernels/edge_3x3.mem", KERNEL_W, signed=True)

preview = cv2.resize(quant_img.astype(np.uint8), (IMG_SIZE * 8, IMG_SIZE * 8),
                      interpolation=cv2.INTER_NEAREST)
cv2.imwrite("Images/input_32x32_preview.png", preview)

print(f"Wrote Images/input_image.mem ({quant_img.shape[0]}x{quant_img.shape[1]}, 8-bit unsigned)")
print("Wrote Images/kernels/edge_3x3.mem (vertical Sobel kernel, 3x3 signed 8-bit)")
print("Wrote Images/input_32x32_preview.png (what the RTL will actually process)")

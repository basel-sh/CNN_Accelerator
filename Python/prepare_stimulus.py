"""
File    : prepare_stimulus.py
Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Step 1 of the run flow: converts Images/input.png into RTL stimulus.
Loads Images/input.png, resizes+quantizes it to 32x32 8-bit unsigned
(matches Testbench/tb_top.v's localparams), and writes a vertical
edge-detection kernel (Sobel X).

Writes:
  Images/input_32x32.mem          <- read by image_memory  (RTL, via tb_top.v)
  Images/kernels/edge_3x3.mem     <- read by kernel_memory (RTL, via tb_top.v)
  Images/input_32x32_preview.png  <- what the RTL will actually "see"

Usage:
    python Python/prepare_stimulus.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cv2
import numpy as np

from image_loader import load_image, write_mem_file

Pixel_W, Kernel_W, Img_Size = 8, 4, 32

Quant_Img = load_image("Images/input.png", Size=(Img_Size, Img_Size), Pixel_Width=Pixel_W)
write_mem_file(Quant_Img, "Images/input_32x32.mem", Pixel_W, Signed=False)

Sobel_Vertical = np.array([[-1, 0, 1],
                            [-2, 0, 2],
                            [-1, 0, 1]], dtype=np.int64)
write_mem_file(Sobel_Vertical, "Images/kernels/edge_3x3.mem", Kernel_W, Signed=True)

Preview = cv2.resize(Quant_Img.astype(np.uint8), (Img_Size * 8, Img_Size * 8),
                      interpolation=cv2.INTER_NEAREST)
cv2.imwrite("Images/input_32x32_preview.png", Preview)

print(f"Wrote Images/input_32x32.mem ({Quant_Img.shape[0]}x{Quant_Img.shape[1]}, 8-bit unsigned)")
print("Wrote Images/kernels/edge_3x3.mem (vertical Sobel kernel, 3x3 signed 8-bit)")
print("Wrote Images/input_32x32_preview.png (what the RTL will actually process)")

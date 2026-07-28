"""
File    : golden_model.py
Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Bit-accurate reference model matching the RTL's fixed-point rules:
  - input pixels  : unsigned, Pixel_Width bits (default 8)
  - kernel coeffs : signed,   Kernel_Width bits (default 8)
  - accumulator/output : signed, Acc_Width bits (default 20, >=16 required)
  - stride = 1, valid convolution (no padding)
  - ReLU optional (clamp negatives to 0), applied AFTER saturation, matching
    output_buffer.v in RTL.
"""

import numpy as np

from convolution import convolve2d
from utilities import quantize_signed, quantize_unsigned


def run_golden_model(Image, Kernel, Apply_Relu=False,
                      Pixel_Width=8, Kernel_Width=8, Acc_Width=20):
    """Run the golden convolution model with RTL-matching fixed-point rules.

    Widths must match the RTL parameters in RTL/mac.v / RTL/kernel_memory.v.
    Returns a signed Acc_Width-bit saturated result, (optionally) ReLU'd,
    exactly like the hardware.
    """
    Image = quantize_unsigned(np.asarray(Image), Pixel_Width)
    Kernel = quantize_signed(np.asarray(Kernel), Kernel_Width)

    Raw = convolve2d(Image, Kernel, Stride=1)
    Saturated = quantize_signed(Raw, Acc_Width)

    if Apply_Relu:
        Saturated = np.clip(Saturated, 0, None)

    return Saturated

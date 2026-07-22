"""
File     : golden_model.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 2 - Python Golden Model

Bit-accurate reference model matching the RTL's fixed-point rules:
  - input pixels  : unsigned, PIXEL_WIDTH bits (default 8)
  - kernel coeffs : signed,   KERNEL_WIDTH bits (default 8)
  - accumulator/output : signed, ACC_WIDTH bits (default 20, >= 16 required)
  - stride = 1, valid convolution (no padding)
  - ReLU optional (clamp negative results to 0), applied AFTER saturation,
    matching how output_buffer.v applies it in RTL.
"""

import numpy as np

from convolution import convolve2d
from utilities import quantize_signed, quantize_unsigned


def run_golden_model(image, kernel, apply_relu=False,
                      pixel_width=8, kernel_width=8, acc_width=20):
    """Run the golden convolution model with RTL-matching fixed-point rules.

    Args:
        image: 2D unsigned array, values in [0, 2^pixel_width - 1].
        kernel: 2D signed array (KxK), values in
                 [-2^(kernel_width-1), 2^(kernel_width-1) - 1].
        apply_relu: clamp negative outputs to zero if True.
        pixel_width, kernel_width, acc_width: fixed-point widths, must match
                 the RTL parameters used in RTL/mac.v / RTL/kernel_memory.v.

    Returns:
        np.ndarray (int64), shape (H-K+1, W-K+1), the golden convolution
        result, saturated to a signed acc_width-bit value and (optionally)
        ReLU'd, exactly like the hardware.
    """
    image = quantize_unsigned(np.asarray(image), pixel_width)
    kernel = quantize_signed(np.asarray(kernel), kernel_width)

    raw = convolve2d(image, kernel, stride=1)
    saturated = quantize_signed(raw, acc_width)

    if apply_relu:
        saturated = np.clip(saturated, 0, None)

    return saturated

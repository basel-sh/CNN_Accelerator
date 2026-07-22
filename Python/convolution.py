"""
File     : convolution.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 2 - Python Golden Model

Generic NxN "valid" convolution (no padding), stride configurable.
Matches the accelerator's assumptions: stride = 1, no zero-padding, so an
HxW input with a KxK kernel produces an (H-K+1) x (W-K+1) output.
"""

import numpy as np


def convolve2d(image, kernel, stride=1):
    """Valid-mode 2D convolution (no padding), arbitrary integer dtype-safe.

    Args:
        image:  2D array-like, shape (H, W).
        kernel: 2D array-like, shape (K, K).
        stride: step size between output pixels (competition spec: 1).

    Returns:
        np.ndarray of dtype int64, shape (out_h, out_w), UNCLAMPED raw sums
        (clamping to the target output width is golden_model.py's job).
    """
    image = np.asarray(image, dtype=np.int64)
    kernel = np.asarray(kernel, dtype=np.int64)

    h, w = image.shape
    k_h, k_w = kernel.shape
    if k_h != k_w:
        raise ValueError("Kernel must be square (NxN).")

    out_h = (h - k_h) // stride + 1
    out_w = (w - k_w) // stride + 1
    if out_h <= 0 or out_w <= 0:
        raise ValueError("Kernel is larger than the image for valid convolution.")

    output = np.zeros((out_h, out_w), dtype=np.int64)
    for oy in range(out_h):
        iy = oy * stride
        for ox in range(out_w):
            ix = ox * stride
            window = image[iy:iy + k_h, ix:ix + k_w]
            output[oy, ox] = int(np.sum(window * kernel))
    return output

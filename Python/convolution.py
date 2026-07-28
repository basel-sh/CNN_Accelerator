"""
File    : convolution.py
Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Generic NxN "valid" convolution (no padding), stride configurable. Matches
the accelerator: stride = 1, no zero-padding, so an HxW input with a KxK
kernel produces an (H-K+1) x (W-K+1) output.
"""

import numpy as np


def convolve2d(Image, Kernel, Stride=1):
    """Valid-mode 2D convolution, dtype-safe.

    Returns int64 array, shape (Out_H, Out_W), UNCLAMPED raw sums
    (clamping to the target output width is golden_model.py's job).
    """
    Image = np.asarray(Image, dtype=np.int64)
    Kernel = np.asarray(Kernel, dtype=np.int64)

    H, W = Image.shape
    K_H, K_W = Kernel.shape
    if K_H != K_W:
        raise ValueError("Kernel must be square (NxN).")

    Out_H = (H - K_H) // Stride + 1
    Out_W = (W - K_W) // Stride + 1
    if Out_H <= 0 or Out_W <= 0:
        raise ValueError("Kernel is larger than the image for valid convolution.")

    Output = np.zeros((Out_H, Out_W), dtype=np.int64)
    for Oy in range(Out_H):
        Iy = Oy * Stride
        for Ox in range(Out_W):
            Ix = Ox * Stride
            Window = Image[Iy:Iy + K_H, Ix:Ix + K_W]
            Output[Oy, Ox] = int(np.sum(Window * Kernel))
    return Output

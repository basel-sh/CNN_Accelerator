"""
File    : image_generator.py
Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Synthetic test-pattern / kernel generators used to stress the RTL beyond a
single natural image (all-zero, all-max, checkerboard, random seeded images,
plus standard edge/blur/identity/sharpen kernels).
"""

import numpy as np


def generate_test_image(Width=32, Height=32, Pattern="random", Seed=0, Pixel_Width=8):
    """Generate a synthetic unsigned test image."""
    Maxval = (1 << Pixel_Width) - 1
    if Pattern == "random":
        Rng = np.random.default_rng(Seed)
        return Rng.integers(0, Maxval + 1, size=(Height, Width), dtype=np.int64)
    if Pattern == "zeros":
        return np.zeros((Height, Width), dtype=np.int64)
    if Pattern == "max":
        return np.full((Height, Width), Maxval, dtype=np.int64)
    if Pattern == "checkerboard":
        Yy, Xx = np.meshgrid(np.arange(Height), np.arange(Width), indexing="ij")
        return np.where((Xx + Yy) % 2 == 0, Maxval, 0).astype(np.int64)
    if Pattern == "gradient":
        Row = np.linspace(0, Maxval, Width, dtype=np.int64)
        return np.tile(Row, (Height, 1))
    raise ValueError(f"Unknown pattern: {Pattern}")


def generate_test_kernel(Size=3, Kind="edge", Kernel_Width=8):
    """Generate a standard signed test kernel of the given size."""
    if Kind == "identity":
        K = np.zeros((Size, Size), dtype=np.int64)
        K[Size // 2, Size // 2] = 1
        return K
    if Kind == "edge":
        if Size != 3:
            raise ValueError("edge kernel is defined for size=3")
        return np.array([[-1, -1, -1],
                          [-1,  8, -1],
                          [-1, -1, -1]], dtype=np.int64)
    if Kind == "sharpen":
        if Size != 3:
            raise ValueError("sharpen kernel is defined for size=3")
        return np.array([[ 0, -1,  0],
                          [-1,  5, -1],
                          [ 0, -1,  0]], dtype=np.int64)
    if Kind == "box_blur":
        # True box blur needs fractional weights (1/size^2); kernel memory
        # only stores integer signed coefficients, so this is unnormalized
        # (all ones) - normalization is a downstream/software concern.
        return np.ones((Size, Size), dtype=np.int64)
    if Kind == "random":
        Lo, Hi = -(1 << (Kernel_Width - 1)), (1 << (Kernel_Width - 1)) - 1
        Rng = np.random.default_rng(1)
        return Rng.integers(Lo, Hi + 1, size=(Size, Size), dtype=np.int64)
    raise ValueError(f"Unknown kernel kind: {Kind}")

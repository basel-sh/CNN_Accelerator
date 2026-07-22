"""
File     : image_generator.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 2 - Python Golden Model

Synthetic test-pattern / kernel generators used to stress the RTL beyond a
single natural image (all-zero, all-max, checkerboard, random seeded images,
and standard edge/blur/identity/sharpen kernels).
"""

import numpy as np


def generate_test_image(width=32, height=32, pattern="random", seed=0, pixel_width=8):
    """Generate a synthetic unsigned test image."""
    maxval = (1 << pixel_width) - 1
    if pattern == "random":
        rng = np.random.default_rng(seed)
        return rng.integers(0, maxval + 1, size=(height, width), dtype=np.int64)
    if pattern == "zeros":
        return np.zeros((height, width), dtype=np.int64)
    if pattern == "max":
        return np.full((height, width), maxval, dtype=np.int64)
    if pattern == "checkerboard":
        yy, xx = np.meshgrid(np.arange(height), np.arange(width), indexing="ij")
        return np.where((xx + yy) % 2 == 0, maxval, 0).astype(np.int64)
    if pattern == "gradient":
        row = np.linspace(0, maxval, width, dtype=np.int64)
        return np.tile(row, (height, 1))
    raise ValueError(f"Unknown pattern: {pattern}")


def generate_test_kernel(size=3, kind="edge", kernel_width=8):
    """Generate a standard signed test kernel of the given size."""
    if kind == "identity":
        k = np.zeros((size, size), dtype=np.int64)
        k[size // 2, size // 2] = 1
        return k
    if kind == "edge":
        if size != 3:
            raise ValueError("edge kernel is defined for size=3")
        return np.array([[-1, -1, -1],
                          [-1,  8, -1],
                          [-1, -1, -1]], dtype=np.int64)
    if kind == "sharpen":
        if size != 3:
            raise ValueError("sharpen kernel is defined for size=3")
        return np.array([[ 0, -1,  0],
                          [-1,  5, -1],
                          [ 0, -1,  0]], dtype=np.int64)
    if kind == "box_blur":
        # Note: true box blur uses fractional weights (1/size^2); the kernel
        # memory only stores integer signed coefficients, so this returns an
        # unnormalized integer box kernel (all ones) - normalization, if
        # desired, is a downstream/software concern, not the RTL's.
        return np.ones((size, size), dtype=np.int64)
    if kind == "random":
        lo, hi = -(1 << (kernel_width - 1)), (1 << (kernel_width - 1)) - 1
        rng = np.random.default_rng(1)
        return rng.integers(lo, hi + 1, size=(size, size), dtype=np.int64)
    raise ValueError(f"Unknown kernel kind: {kind}")

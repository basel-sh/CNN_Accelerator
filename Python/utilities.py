"""
File     : utilities.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 2 - Python Golden Model (shared helpers)

Shared fixed-point quantize/saturate helpers and Matplotlib visualization,
used across the rest of Python/.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")  # headless-safe backend; GUI backend used automatically if a display exists
import matplotlib.pyplot as plt


def quantize_unsigned(value, width):
    """Clamp/saturate a value (or array) into an unsigned [0, 2^width - 1] range."""
    lo, hi = 0, (1 << width) - 1
    return np.clip(value, lo, hi).astype(np.int64)


def quantize_signed(value, width):
    """Clamp/saturate a value (or array) into a signed [-2^(width-1), 2^(width-1)-1] range."""
    lo, hi = -(1 << (width - 1)), (1 << (width - 1)) - 1
    return np.clip(value, lo, hi).astype(np.int64)


def to_twos_complement_hex(value, width):
    """Convert a signed Python/NumPy int into its two's-complement hex string of `width` bits."""
    value = int(value)
    mask = (1 << width) - 1
    return format(value & mask, "0{}x".format((width + 3) // 4))


def from_twos_complement(hex_str, width):
    """Convert a two's-complement hex string of `width` bits back into a signed Python int."""
    value = int(hex_str, 16)
    sign_bit = 1 << (width - 1)
    if value & sign_bit:
        value -= (1 << width)
    return value


def plot_image(array, title="", save_path=None):
    """Visualize a 2D array (image, kernel, or convolution result) with Matplotlib."""
    fig, ax = plt.subplots()
    im = ax.imshow(array, cmap="gray")
    ax.set_title(title)
    fig.colorbar(im, ax=ax)
    if save_path:
        fig.savefig(save_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    return save_path

"""
File    : utilities.py
Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Shared fixed-point quantize/saturate helpers + a Matplotlib image plotter,
used across the rest of Python/.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")  # headless-safe backend; GUI backend used automatically if a display exists
import matplotlib.pyplot as plt


def quantize_unsigned(Value, Width):
    """Saturate a value/array into unsigned [0, 2^Width - 1]."""
    Lo, Hi = 0, (1 << Width) - 1
    return np.clip(Value, Lo, Hi).astype(np.int64)


def quantize_signed(Value, Width):
    """Saturate a value/array into signed [-2^(Width-1), 2^(Width-1)-1]."""
    Lo, Hi = -(1 << (Width - 1)), (1 << (Width - 1)) - 1
    return np.clip(Value, Lo, Hi).astype(np.int64)


def to_twos_complement_hex(Value, Width):
    """Signed int -> Width-bit two's-complement hex string."""
    Value = int(Value)
    Mask = (1 << Width) - 1
    return format(Value & Mask, "0{}x".format((Width + 3) // 4))


def from_twos_complement(Hex_Str, Width):
    """Width-bit two's-complement hex string -> signed int."""
    Value = int(Hex_Str, 16)
    Sign_Bit = 1 << (Width - 1)
    if Value & Sign_Bit:
        Value -= (1 << Width)
    return Value


def plot_image(Array, Title="", Save_Path=None):
    """Visualize a 2D array (image, kernel, or result) with Matplotlib."""
    Fig, Ax = plt.subplots()
    Im = Ax.imshow(Array, cmap="gray")
    Ax.set_title(Title)
    Fig.colorbar(Im, ax=Ax)
    if Save_Path:
        Fig.savefig(Save_Path, dpi=150, bbox_inches="tight")
    plt.close(Fig)
    return Save_Path

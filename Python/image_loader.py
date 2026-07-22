"""
File     : image_loader.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 2 - Python Golden Model

Loads/quantizes images with OpenCV and exports/imports Verilog
$readmemh-compatible hex memory files, so Python and RTL simulation consume
byte-for-byte identical stimulus.
"""

import os
import numpy as np
import cv2

from utilities import quantize_unsigned, quantize_signed, to_twos_complement_hex, from_twos_complement


def load_image(path, size=None, pixel_width=8):
    """Load an image file, convert to grayscale, optionally resize, quantize."""
    img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise FileNotFoundError(f"Could not read image: {path}")
    if size is not None:
        img = cv2.resize(img, size, interpolation=cv2.INTER_AREA)
    return quantize_unsigned(img.astype(np.int64), pixel_width)


def save_image(array, path):
    """Save a 2D array as a PNG (values clipped to [0,255])."""
    arr = np.clip(np.asarray(array), 0, 255).astype(np.uint8)
    cv2.imwrite(path, arr)


def write_mem_file(array, out_path, width, signed=False):
    """Write a 2D array to a $readmemh-compatible hex file, one value per
    line, in row-major (raster) order — the order RTL/image_memory.v and
    RTL/kernel_memory.v are addressed in."""
    flat = np.asarray(array).flatten()
    with open(out_path, "w") as f:
        for v in flat:
            if signed:
                v = int(quantize_signed(np.array([v]), width)[0])
                f.write(to_twos_complement_hex(v, width) + "\n")
            else:
                v = int(quantize_unsigned(np.array([v]), width)[0])
                f.write(format(v, "0{}x".format((width + 3) // 4)) + "\n")


def read_mem_file(path, shape, width, signed=False):
    """Read back a $readmemh-style hex file into a 2D array of the given shape."""
    values = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if signed:
                values.append(from_twos_complement(line, width))
            else:
                values.append(int(line, 16))
    arr = np.array(values, dtype=np.int64)
    return arr.reshape(shape)

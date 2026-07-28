"""
File    : image_loader.py
Project : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026

Loads/quantizes images with OpenCV and exports/imports Verilog
$readmemh-compatible hex memory files, so Python and RTL simulation consume
byte-for-byte identical stimulus.
"""

import os
import numpy as np
import cv2

from utilities import quantize_unsigned, quantize_signed, to_twos_complement_hex, from_twos_complement


def load_image(Path, Size=None, Pixel_Width=8):
    """Load an image, convert to grayscale, optionally resize, quantize."""
    Img = cv2.imread(Path, cv2.IMREAD_GRAYSCALE)
    if Img is None:
        raise FileNotFoundError(f"Could not read image: {Path}")
    if Size is not None:
        Img = cv2.resize(Img, Size, interpolation=cv2.INTER_AREA)
    return quantize_unsigned(Img.astype(np.int64), Pixel_Width)


def save_image(Array, Path):
    """Save a 2D array as a PNG (values clipped to [0,255])."""
    Arr = np.clip(np.asarray(Array), 0, 255).astype(np.uint8)
    cv2.imwrite(Path, Arr)


def write_mem_file(Array, Out_Path, Width, Signed=False):
    """Write a 2D array to a $readmemh-compatible hex file, one value per
    line, in row-major (raster) order - the order RTL/image_memory.v and
    RTL/kernel_memory.v are addressed in."""
    Flat = np.asarray(Array).flatten()
    with open(Out_Path, "w") as F:
        for V in Flat:
            if Signed:
                V = int(quantize_signed(np.array([V]), Width)[0])
                F.write(to_twos_complement_hex(V, Width) + "\n")
            else:
                V = int(quantize_unsigned(np.array([V]), Width)[0])
                F.write(format(V, "0{}x".format((Width + 3) // 4)) + "\n")


def read_mem_file(Path, Shape, Width, Signed=False):
    """Read a $readmemh-style hex file back into a 2D array of Shape."""
    Values = []
    with open(Path) as F:
        for Line in F:
            Line = Line.strip()
            if not Line:
                continue
            if Signed:
                Values.append(from_twos_complement(Line, Width))
            else:
                Values.append(int(Line, 16))
    Arr = np.array(Values, dtype=np.int64)
    return Arr.reshape(Shape)

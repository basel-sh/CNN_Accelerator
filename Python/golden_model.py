"""
File     : golden_model.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 2 - Python Golden Model (see Documentation/DevelopmentRoadmap.md)

Responsibility
--------------
Reference ("golden") NxN convolution implementation used as the ground truth
that the RTL simulation output is checked against. Must faithfully model the
same fixed-point/quantization rules as the RTL: unsigned input pixels,
signed 8-bit kernel coefficients, signed >=16-bit accumulation, stride = 1,
and optional ReLU.

Interacts with
--------------
- convolution.py   (may reuse/compare against a NumPy convolution reference)
- image_loader.py  (loads the input image/feature map)
- verify.py        (calls this module to generate the expected output)

Status: STUB ONLY - no implementation yet.
"""

def run_golden_model(image, kernel, apply_relu=False):
    """TODO (Phase 2): implement bit-accurate golden convolution model.

    Args:
        image: unsigned fixed-point 2D array (>=32x32 grayscale).
        kernel: signed 8-bit NxN kernel coefficients.
        apply_relu: whether to clamp negative outputs to zero.

    Returns:
        signed >=16-bit 2D output array.
    """
    raise NotImplementedError("Implement in Phase 2 - Python Golden Model")

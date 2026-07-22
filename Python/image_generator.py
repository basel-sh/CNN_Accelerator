"""
File     : image_generator.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 2 - Python Golden Model

Responsibility
--------------
Synthetic test-pattern / kernel generator (edge cases: all-zero, all-max,
checkerboard, random seeded images, identity/edge/blur kernels) used to
stress the RTL beyond a single natural image.

Interacts with
--------------
- Images/, Images/kernels/
- golden_model.py, verify.py

Status: STUB ONLY - no implementation yet.
"""

def generate_test_image(width=32, height=32, pattern="random", seed=0):
    """TODO (Phase 2): implement synthetic test image generation."""
    raise NotImplementedError("Implement in Phase 2 - Python Golden Model")


def generate_test_kernel(size=3, kind="edge"):
    """TODO (Phase 2): implement standard test kernel generation."""
    raise NotImplementedError("Implement in Phase 2 - Python Golden Model")

"""
File     : image_loader.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 2 - Python Golden Model

Responsibility
--------------
Load input images (PNG etc. via OpenCV) from Images/, convert to grayscale,
and quantize to the unsigned fixed-point format expected by the accelerator.
Also handles writing memory-init files (.mem/.hex) consumed by RTL simulation.

Interacts with
--------------
- Images/input.png
- golden_model.py, verify.py
- Testbench/tb_top.v (via generated .mem/.hex stimulus files)

Status: STUB ONLY - no implementation yet.
"""

def load_image(path):
    """TODO (Phase 2): load + grayscale + quantize an input image."""
    raise NotImplementedError("Implement in Phase 2 - Python Golden Model")


def write_mem_file(array, out_path):
    """TODO (Phase 2): export array as a Verilog $readmemh-compatible file."""
    raise NotImplementedError("Implement in Phase 2 - Python Golden Model")

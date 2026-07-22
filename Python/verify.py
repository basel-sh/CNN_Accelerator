"""
File     : verify.py
Project  : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
Phase    : 9 - Simulation / Verification

Responsibility
--------------
Automatic PASS/FAIL comparison pipeline: runs the golden model on the same
image/kernel used by the RTL testbench, parses the RTL simulation output
(dumped by tb_top.v), compares element-by-element, and reports mismatches.
This is the final stage of the verification pipeline described in
Documentation/Architecture.md.

Interacts with
--------------
- golden_model.py, image_loader.py
- Testbench/tb_top.v (consumes its simulation output file)
- Scripts/run_simulation.tcl (invoked after simulation completes)

Status: STUB ONLY - no implementation yet.
"""

def compare_outputs(golden, rtl_output, tolerance=0):
    """TODO (Phase 9): implement PASS/FAIL comparison + mismatch reporting."""
    raise NotImplementedError("Implement in Phase 9 - Simulation")


def main():
    """TODO (Phase 9): CLI entry point wiring golden model -> RTL -> compare."""
    raise NotImplementedError("Implement in Phase 9 - Simulation")


if __name__ == "__main__":
    main()

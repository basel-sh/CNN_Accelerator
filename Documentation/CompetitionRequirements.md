# Competition Requirements — IEEE SSCS Egypt Chapter 2026 Student Design Competition

## Functional Requirements

| # | Requirement | Notes for this project |
|---|---|---|
| 1 | Accept at least a 32x32 grayscale image or feature map | `image_memory.v` sized for >=32x32; `Python/image_loader.py` loads/quantizes it |
| 2 | Perform NxN convolution | N is a parameter; default target 3x3, extensible |
| 3 | Kernel coefficients are programmable | `kernel_memory.v` is writable at runtime, not hard-coded |
| 4 | Input is unsigned fixed-point | Pixel datapath is unsigned throughout |
| 5 | Kernel is signed 8-bit | `kernel_memory.v` stores signed 8-bit coefficients |
| 6 | Output is minimum signed 16-bit | `mac.v` accumulator and `output_buffer.v` are >=16-bit signed |
| 7 | Stride = 1 | `window_generator.v` advances one pixel per step |
| 8 | ReLU is optional | Controlled by `controller.v` (enable bit), applied before/at `output_buffer.v` |
| 9 | Verification against a Python/C++/MATLAB golden model | `Python/golden_model.py` + `Python/verify.py` |
| 10 | FPGA synthesis reports required | `Reports/synthesis/`, produced via `Scripts/synthesize.tcl` |
| 11 | Timing reports required | `Reports/timing/` |
| 12 | Power reports required | `Reports/power/` |

## Evaluation Criteria

| Category | Where addressed in this project |
|---|---|
| Correctness | Golden-model vs RTL simulation comparison pipeline (`Python/verify.py`) |
| Architecture quality | `Documentation/Architecture.md` |
| Resource utilization (LUT/DSP/BRAM) | `Reports/utilization/`, discussed against `mac.v` and `ram.v` design choices |
| Throughput / Latency | Measured from simulation waveforms + architecture pipelining (Architecture.md) |
| Timing closure / Fmax | `Reports/timing/`, `Vivado/constraints.xdc` |
| Power | `Reports/power/` |
| Figure of Merit (FoM) | Computed at Phase 14 from the above metrics (see DevelopmentRoadmap.md) |

## Traceability

Every functional requirement above maps to a specific RTL module (see
`Documentation/FileGuide.md`) and a specific development phase (see
`Documentation/DevelopmentRoadmap.md`), so no requirement is at risk of being
missed during implementation.

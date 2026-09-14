# Competition Requirements — IEEE SSCS Egypt Chapter 2026 Student Design Competition

Source: `2026 SSCS_Egypt Competition Announcement.pdf` (repo root).
Registration deadline **July 25, 2026**. Report due **September 15, 2026**;
winners announced **September 30, 2026**. Awards: Gold $350, Silver $250,
Bronze $150.

Figure of Merit:

```
FoM = Throughput / (Power x (LUTs + 50*DSPs + 100*BRAMs))
```
where Throughput is in output pixels/cycle. Higher is better. Final value:
**1.777e-2** (re-synthesized 2026-09-13/14, the output-FIFO fix, the
K-generalized MAC reduction, and the kernel-scoped bit-width optimization are
all included) — the best FoM of every phase this project went through. See
`Documentation/PerformanceResults.md`.

## Functional Requirements

| # | Requirement | Notes for this project |
|---|---|---|
| 1 | Accept at least a 32x32 grayscale image or feature map | `image_memory_2px.v` sized for >=32x32; `Python/image_loader.py` loads/quantizes it |
| 2 | Perform NxN convolution | N is a parameter; default target 3x3, extensible |
| 3 | Kernel coefficients are programmable | `kernel_memory.v` is writable at runtime, not hard-coded |
| 4 | Input is unsigned fixed-point | Pixel datapath is unsigned throughout |
| 5 | Kernel is signed 8-bit | `kernel_memory.v` stores signed coefficients; 4 bits used (`\|coeff\| <= 8`), scoped to this design's kernel class — see `PerformanceResults.md` |
| 6 | Output is minimum signed 16-bit | `mac_pair.v` accumulator is 16-bit signed, exactly at the minimum by deliberate choice (narrowed from a fully-general 20-bit; see `PerformanceResults.md` for the overflow proof and scoping rationale) |
| 7 | Stride = 1 | `window_generator_2px.v` advances one pixel per lane per cycle |
| 8 | ReLU is optional | `Relu_En` input, applied inline at `top_2px.v`'s output mux |
| 9 | Verification against a Python/C++/MATLAB golden model | `Python/golden_model.py` + `Python/verify.py`, plus a separate Icarus Verilog regression suite (`Testbench/audit_icarus_2026-09-12/`) and a 46-row formal test plan (`Verification_Test_Plan.xlsx`) |
| 10 | FPGA synthesis reports required | `Reports/` (routed, `Scripts/synthesize_2px.tcl`) |
| 11 | Timing reports required | `Reports/timing/` — WNS +33.802 ns, all constraints met |
| 12 | Power reports required | `Reports/power/` — 0.113 W total |
| Bonus | AXI4-Lite bus interface | `RTL/axi_lite_top_2px.v`, verified with its own bus-functional testbench (`tb_axi_lite.v`) |

## Evaluation Criteria

| Category | Where addressed in this project |
|---|---|
| Correctness | Golden-model vs RTL simulation comparison pipeline (`Python/verify.py`), 900/900 on every kernel/image case tried, plus the Icarus regression suite and formal test plan |
| Architecture quality | `Documentation/Architecture.md`, plus the design-space trail in `OptimizationLog.md`/`Aggressive2px.md` showing why the DSP-sharing alternative was rejected |
| Resource utilization (LUT/DSP/BRAM) | `Reports/utilization/`, discussed against `mac_pair.v` and `image_memory_2px.v` design choices |
| Throughput / Latency | 2 output pixels/cycle, measured from simulation + `Architecture.md` pipeline description |
| Timing closure / Fmax | `Reports/timing/`, `Vivado_2px/constraints_2px.xdc` |
| Power | `Reports/power/` |
| Figure of Merit (FoM) | 1.777e-2 — `Documentation/PerformanceResults.md` |

## Traceability

Every functional requirement above maps to a specific RTL module (see
`Documentation/FileGuide.md`).

# CNN Convolution Accelerator

FPGA-based Edge-AI CNN Convolution Accelerator — IEEE SSCS Egypt Chapter 2026
Student Design Competition.

> Status: **infrastructure only**. RTL, golden model, and reports are not yet
> implemented — see `Documentation/DevelopmentRoadmap.md` for the phased
> implementation plan this repository is scaffolded for.

## Project Overview

This project implements a programmable NxN convolution accelerator for
grayscale images / CNN feature maps on Xilinx FPGA, targeting edge-AI
inference. It accepts an unsigned fixed-point image, applies a signed 8-bit
programmable kernel at stride 1, accumulates into a signed >=16-bit result,
with optional ReLU — and is verified bit-for-bit against a Python golden
model before any FPGA synthesis is trusted.

## Competition Description

Design an FPGA-based Edge-AI CNN Convolution Accelerator that:

- Accepts at least a 32x32 grayscale image or feature map
- Performs NxN convolution with programmable kernel coefficients
- Uses unsigned fixed-point input, signed 8-bit kernel, signed >=16-bit output
- Runs at stride = 1, with optional ReLU
- Is verified against a Python/C++/MATLAB golden model
- Reports synthesis, timing, and power results

Full requirement-to-file traceability: `Documentation/CompetitionRequirements.md`.

## Folder Structure

```
CNN_Accelerator/
├── RTL/            Verilog source modules (accelerator datapath + control)
├── Testbench/      Verilog testbenches
├── Python/         Golden model, image tooling, verification scripts
├── Images/         Test images and programmable kernel sets
├── Reports/        synthesis/ timing/ utilization/ power/ (Vivado exports)
├── Vivado/         Vivado project + constraints
├── Presentation/   Final competition deliverable (slides, plots)
├── Documentation/  Architecture, roadmap, requirements, file guide
├── Scripts/        Tcl scripts for build / simulate / synthesize
├── .gitignore
├── README.md
├── requirements.txt
└── LICENSE
```

See `Documentation/FileGuide.md` for a per-file explanation of purpose,
responsibility, and interactions.

## Required Software

- Xilinx Vivado (Design Suite, with a supported 7-series/UltraScale part)
- Verilog HDL (simulated/synthesized via Vivado)
- Python 3.10+
- NumPy, OpenCV, Matplotlib, pytest (see `requirements.txt`)
- Visual Studio Code
- Git / GitHub
- Optional: ModelSim, GTKWave (alternative simulation/waveform viewing)

## Installation

```bash
git clone <this-repo-url> CNN_Accelerator
cd CNN_Accelerator
```

## Python Environment Setup

```bash
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Vivado Setup

**Option A — scripted (recommended once RTL exists):**
```tcl
vivado -mode batch -source Scripts/build.tcl
```

**Option B — manual, via Vivado GUI:**
1. Create Project → RTL Project → name `CNN_Accelerator`, location `Vivado/`.
2. Add Sources → add all files under `RTL/` as design sources.
3. Add Sources → add all files under `Testbench/` as simulation sources.
4. Add Constraints → add `Vivado/constraints.xdc`.
5. Select the target part/board for your FPGA.
6. Set `top` (from `RTL/top.v`) as the top module for synthesis, and the
   relevant `tb_*.v` as the top module for simulation.

## Build Flow

1. `Scripts/build.tcl` creates/opens the Vivado project and adds sources.
2. `RTL/` changes are picked up automatically on next `update_compile_order`.

## Simulation Flow

1. Generate stimulus: `Python/image_loader.py` + `Python/image_generator.py`
   produce a quantized image and kernel, exported as `$readmemh`-compatible
   files consumed by `Testbench/tb_top.v`.
2. Run `Scripts/run_simulation.tcl` (or launch simulation from the Vivado
   GUI / ModelSim) targeting `tb_top.v`.
3. RTL output is dumped to a text/log file for comparison.

## Verification Flow

```
Input Image
   │
   ▼
Python Golden Model (Python/golden_model.py)
   │
   ▼
Expected Output
   │
   ▼
RTL Simulation (Testbench/tb_top.v)
   │
   ▼
RTL Output
   │
   ▼
Automatic Comparison (Python/verify.py)
   │
   ▼
PASS / FAIL
```

Run once implemented:
```bash
python Python/verify.py
```

## Synthesis Flow

1. `Scripts/synthesize.tcl` runs `launch_runs synth_1` then
   `launch_runs impl_1`.
2. Reports are exported automatically to `Reports/utilization/`,
   `Reports/timing/`, and `Reports/power/`.
3. Manual alternative (Vivado GUI): Run Synthesis → Run Implementation →
   Open Implemented Design → Report Utilization / Report Timing Summary /
   Report Power, then File → Export → export each report into the
   corresponding `Reports/` subfolder.

## Reports

| Folder | Content |
|---|---|
| `Reports/synthesis/` | Synthesis run logs/reports |
| `Reports/utilization/` | LUT / DSP / BRAM utilization reports |
| `Reports/timing/` | Timing summary, Fmax, slack reports |
| `Reports/power/` | Power analysis reports |

## Development Roadmap

14 phases from project setup through final report — full detail in
`Documentation/DevelopmentRoadmap.md`:

1. Project Setup · 2. Python Golden Model · 3. Memory Architecture ·
4. Line Buffer · 5. Window Generator · 6. MAC Unit · 7. Controller FSM ·
8. Top Integration · 9. Simulation · 10. Optimization · 11. Synthesis ·
12. Timing Closure · 13. Power Optimization · 14. Final Report

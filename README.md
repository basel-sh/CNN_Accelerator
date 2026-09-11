# CNN Convolution Accelerator

FPGA-based edge-AI `K x K` convolution accelerator, built for the **IEEE SSCS Egypt
Chapter 2026 Student Design Competition**. Programmable kernel, unsigned pixel input,
signed 8-bit kernel, stride 1, optional ReLU — verified bit-exact against a Python
golden model before any synthesis number is trusted.

> **Status: done.** RTL, simulation, synthesis, timing closure and power are all
> complete on both the 1px/cycle baseline (`master`) and the 2px/cycle optimized
> version (`aggressive-2px-fom`). Final Figure of Merit: **1.10e-2** (2px/cycle,
> zero DSPs, timing closed) — see the results table below.

---

## 1. What this is

A programmable convolution accelerator for grayscale images / CNN feature maps,
targeting a Xilinx 7-series FPGA (`xc7a35tcpg236-1`):

- Unsigned fixed-point input pixels, signed 8-bit programmable kernel coefficients
- Stride = 1, optional ReLU
- Signed >=16-bit accumulator/output (20-bit, sized for the worst-case 3x3/8-bit sum)
- Two versions in this repo: the straightforward 1 output-pixel/cycle design
  (`master`), and a 2 outputs/cycle version (`aggressive-2px-fom`) that doubles
  throughput without adding a single DSP

## 2. Results — Figure of Merit

`FoM = Throughput / (Power x (LUT + 50*DSP + 100*BRAM))`, Throughput in output
pixels/cycle. Higher is better. Full history of every phase that led here:
`Reports/README.md` and `Documentation/OptimizationLog.md` / `Aggressive2px.md`.

| Design | Branch | Throughput | LUT | FF | DSP | BRAM | Power (W) | WNS (ns) | FoM |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1px baseline | `master` | 1 | 842 | 758 | 0 | 0.5 | 0.149 | +35.538 | 7.52e-3 |
| 2px, 4-DSP (abandoned) | `aggressive-2px-fom` | 2 | 738 | 1286 | 4 | 1.0 | 0.233 | -4.338 (FAILED) | 8.27e-3, not valid |
| **2px, 0-DSP (adopted)** | `aggressive-2px-fom` | 2 | 1411 | 638 | 0 | 1.0 | 0.120 | **+35.076 (PASS)** | **1.10e-2** |

The 2px/0-DSP design is the one worth reporting: it's the only 2 px/cycle version
that actually closes timing, and it beats the 1px baseline by **+46.6%**. It got
there by dropping the idea of sharing a few DSPs over a second, faster clock (that
needs CDC FIFOs and a 120 MHz domain that never closed timing) and instead just runs
all 18 products/pair through fabric multipliers on the same 20 MHz clock as
everything else — same pipeline depth as the baseline, just twice as wide.

## 3. Quick start — run the 1px baseline right now

Three steps, three tools, from the repo root.

| # | Where | Command |
|---|---|---|
| 1 | terminal | `python Python/prepare_stimulus.py` |
| 2 | Vivado Tcl console | `cd {C:/Users/Xps/Desktop/CNN_Accelerator}` then `source Scripts/run_simulation.tcl` |
| 3 | terminal | `python Python/mem_to_image.py` |

Step 2 also runs `Python/verify.py` internally and prints PASS/FAIL to the Tcl
console. No Vivado handy? Use the Icarus fast path instead of step 2 (same RTL,
same testbench, same golden model):

```bash
bash Scripts/run_simulation_iverilog.sh
```

### First-time setup

```bash
git clone https://github.com/basel-sh/CNN_Accelerator.git
cd CNN_Accelerator
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

`Vivado/CNN_Accelerator.xpr` is tracked in the repo, so just open it in Vivado — no
need to run `Scripts/build.tcl` first. If you ever need to recreate it from scratch:
`vivado -mode batch -source Scripts/build.tcl`. Same pattern for the 2px project
(`Vivado_2px/`, `Scripts/build_2px.tcl`) and the abandoned 4-DSP one
(`Vivado_2px_MP4/`, `Scripts/build_2px_mp4.tcl`).

**Required:** Xilinx Vivado (7-series), Python 3.10+ (NumPy, OpenCV, Matplotlib —
`requirements.txt`), VS Code, Git. Optional: Icarus Verilog + GTKWave.

## 4. Command reference — everything I actually run

### Python / VS Code terminal

| Command | What it does |
|---|---|
| `python Python/prepare_stimulus.py` | Resizes/quantizes `Images/input.png` to 32x32, writes `Images/input_32x32.mem` + a preview PNG, and writes the test kernel to `Images/kernels/edge_3x3.mem` |
| `python Python/mem_to_image.py` | Turns `sim/rtl_output.mem` (or `_2px.mem`) back into a viewable PNG |
| `python Python/verify.py --image Images/input_32x32.mem --kernel Images/kernels/edge_3x3.mem --rtl-output sim/rtl_output.mem --img-size 32 32 --k 3 --acc-width 20` | 1px baseline: compares RTL sim output to the golden model, element by element |
| same, with `--rtl-output sim/rtl_output_2px.mem` | 2px, zero-DSP version |
| same, with `--rtl-output sim/rtl_output_2px_mp4.mem` | 2px, 4-DSP version (abandoned, kept for reference) |
| `bash Scripts/run_simulation_iverilog.sh` | Full sim + verify without Vivado, using Icarus |

### Vivado Tcl console

Always `cd {C:/Users/Xps/Desktop/CNN_Accelerator}` first if the console doesn't
already sit at the repo root.

| Command | What it does |
|---|---|
| `source Scripts/run_simulation.tcl` | Behavioral sim of the 1px baseline (`top.v`), writes `sim/rtl_output.mem` |
| `source Scripts/run_simulation_2px.tcl` | Behavioral sim of the 2px zero-DSP design (`top_2px.v`), writes `sim/rtl_output_2px.mem` |
| `source Scripts/run_simulation_2px_mp4.tcl` | Behavioral sim of the abandoned 4-DSP design |
| `source Scripts/synthesize_2px.tcl` | Full synth + routed implementation of `top_2px`, exports to `Reports/2px/` |
| `source Scripts/synthesize_2px_mp4.tcl` | Same, for the abandoned 4-DSP design, exports to `Reports/2px_mp4/` |

**The habit that matters most:** always run the matching `run_simulation*.tcl` and
confirm `900 output values` / `RESULT: PASS` in the verify step **before** running a
synthesize script. A synthesis run that isn't backed by a fresh PASS is a wasted
20+ minutes if the RTL changed since the last verified sim.

The 1px baseline's `Scripts/synthesize.tcl` is still a placeholder — those reports
(`Reports/1px_baseline/`) were captured by hand: Vivado GUI -> Run Synthesis -> Run
Implementation -> Report Utilization / Timing Summary / Power -> export.

## 5. How it works

```
Python (prepare_stimulus.py):
  input.png --resize+quantize--> [32x32 array] --+--> input_32x32.mem
                                                   +--> input_32x32_preview.png
                                  (also writes kernels/edge_3x3.mem, vertical-Sobel)

RTL (Vivado, run_simulation*.tcl):
  input_32x32.mem + kernels/edge_3x3.mem --> sim/rtl_output*.mem

Python (mem_to_image.py):
  sim/rtl_output*.mem --> rtl_output_preview.png
```

## 6. Accelerator architecture

### 1px/cycle baseline (`master`)

```
kernel load ──▶ kernel_memory.v                    controller.v (FSM)
                                                     drives raster-scan
image stream ──▶ image_memory.v ──▶ line_buffer.v ──▶ window_generator.v
                (row-major read)   (K-1 row delay)   (assembles KxK window)
                                                              │
                                                              ▼
                                                           mac.v
                                                (9 fabric multiplies, balanced
                                                 adder tree, 2-stage pipeline)
                                                              │
                                                              ▼
                                                     output_buffer.v
                                              (optional ReLU, FIFO stream out)
```

### 2px/cycle, zero-DSP (`aggressive-2px-fom`, adopted)

Same idea, widened: `image_memory_2px.v` reads two pixels/cycle off a dual-port
BRAM, `line_buffer_2px.v` / `window_generator_2px.v` build two overlapping 3x3
windows per cycle, and `mac_pair.v` runs all 18 products (9 per window — the
overlap doesn't let you reuse products, because a shifted window pairs each shared
pixel with a different kernel coefficient) through the same multiply -> register ->
adder-tree -> register pipeline as the baseline, just twice as wide. One clock
(20 MHz) for everything — no DSPs, no second clock domain, no CDC logic.

`top.v` / `top_2px.v` wire each variant together and align pipeline latency so the
valid-window tag stays in lockstep with the data. Full detail: `Documentation/
Architecture.md` (baseline) and `Documentation/Aggressive2px.md` (2px, including
the abandoned 4-DSP attempt and why it was dropped).

## 7. Folder structure

```
CNN_Accelerator/
├── RTL/             Verilog: top.v / top_2px.v / top_2px_mp4.v + all submodules
├── Testbench/        Verilog + SystemVerilog testbenches for each top-level
├── Python/           Golden model, image tooling, verification script
├── Images/           Test images, preview PNGs, programmable kernels
├── Vivado/           1px baseline Vivado project + constraints
├── Vivado_2px/        2px zero-DSP Vivado project + constraints
├── Vivado_2px_MP4/     2px 4-DSP Vivado project + constraints (abandoned)
├── Scripts/          Tcl build/simulate/synthesize scripts + Icarus fast path
├── Reports/          synthesis/timing/utilization/power per design, see Reports/README.md
├── Presentation/     Competition slide deck
├── Documentation/    Architecture, roadmap, requirements, optimization log, file guide
├── .gitignore, README.md, requirements.txt, LICENSE
```

Per-file purpose: `Documentation/FileGuide.md`.

## 8. Naming convention

Every signal, port, parameter, and Python variable follows one rule: multi-word
names are written `First_Second` (each word capitalized, joined by `_`, never
abbreviated mid-word). Module/function/file names are kept as-is, since Verilog
module names are referenced directly inside the Vivado `.xpr` project files —
renaming them would mean hand-editing those project files.

## 9. Verification

```
Input Image ──▶ Python Golden Model (golden_model.py) ──▶ Expected Output
                                                                  │
RTL Simulation (Testbench/tb_top*.v) ──▶ RTL Output ──▶ Compare (verify.py) ──▶ PASS/FAIL
```

| Testbench | Result |
|---|---|
| `tb_mac.v` | 3/3 hand-computed vectors passed |
| `tb_controller.v` | address sequencing + valid-window count exact |
| `tb_top.v` (1px baseline) | **900/900 outputs bit-exact** vs. the golden model |
| `tb_top_2px.v` (2px, zero-DSP, adopted) | **900/900 outputs bit-exact**, same image/kernel |
| `tb_top_2px_mp4.v` (2px, 4-DSP, abandoned) | 900/900 bit-exact in sim, but never closed timing |

Full detail: `Documentation/VerificationResults.md`.

## 10. Competition requirements checklist

Source: `2026 SSCS_Egypt Competition Announcement.pdf` (repo root). Registration
deadline was July 25, 2026; report due September 15, 2026; winners announced
September 30, 2026.

| # | Requirement | Status | Where |
|---|---|---|---|
| 1 | Min. 32x32 grayscale image/feature map input | Done | `Img_W`/`Img_H` = 32, both tops (parameterizable) |
| 2 | Input precision: unsigned fixed-point | Done | `Pixel_W`-bit unsigned datapath |
| 3 | Programmable NxN kernel | Done | `RTL/kernel_memory.v`, runtime-writable |
| 4 | Kernel precision: 8-bit signed | Done | `Kernel_W = 8`, signed |
| 5 | Stride = 1 | Done | `window_generator*.v` |
| 6 | Output precision: min. 16-bit signed | Done | `Acc_W = 20` signed, overflow-proof by construction (see `Documentation/PerformanceResults.md`) |
| 7 | ReLU activation (bonus) | Done | `Relu_En`, applied in `output_buffer.v` / at the top-level output mux |
| 8 | Verified against a golden model | Done | `Python/golden_model.py` + `verify.py`, 900/900 on every variant |
| 9 | Synthesis/implementation results (LUT/FF/DSP/BRAM/Fmax/timing/power) | Done | `Reports/` — see §2 above |
| 10 | Figure of Merit | Done | 1.10e-2, `Reports/README.md` |

## 11. Development history

| Phase | Name | Result |
|---|---|---|
| 1-9 | Setup -> golden model -> memory/line buffer/window/MAC/controller/top -> sim | 900/900, bit-exact |
| 10 | FoM optimization pass (1px) | Killed an oversized 1024-deep output FIFO that synthesized as ~20k FFs, fixed two reset-hazard DRC violations, settled on 20 MHz. 7396->842 LUT, 20966->758 FF, FoM 3.96e-4 -> 7.52e-3 (~19x) |
| 11-13 | 2px/cycle exploration (`aggressive-2px-fom`) | Tried sharing 4 DSPs over a 120 MHz second clock (`top_2px_mp4`) — functionally correct, but WNS = -4.338 ns, never closed. Abandoned in favor of `top_2px` + `mac_pair.v`: same 20 MHz clock, 18 fabric multipliers, zero DSP, zero CDC logic. Closes timing at +35.076 ns |
| 14 | Final report / FoM | 1.10e-2, +46.6% over the 1px baseline, this file + `Reports/README.md` |

Full detail: `Documentation/DevelopmentRoadmap.md`, `Documentation/OptimizationLog.md`,
`Documentation/Aggressive2px.md`.

## 12. License

See `LICENSE`.

# CNN Convolution Accelerator

FPGA-based Edge-AI NxN CNN convolution accelerator — built for the **IEEE
SSCS Egypt Chapter 2026 Student Design Competition**.

> **Status: implemented & verified.** RTL (Phases 1-9) is complete and
> passes bit-exact simulation against the Python golden model. Synthesis,
> timing, and power (Phases 10-14) are pending — they require the Vivado
> GUI on your machine. See `Documentation/DevelopmentRoadmap.md`.

---

## 1. What this is

A programmable `K x K` convolution accelerator for grayscale images / CNN
feature maps, targeting Xilinx FPGAs:

- Unsigned fixed-point input pixels, signed 8-bit programmable kernel
- Stride = 1, optional ReLU
- Signed >=16-bit accumulator/output
- Verified bit-for-bit against a Python golden model before any synthesis
  is trusted

## 2. Quick Start — run it right now

Three steps, three tools. Run them in order from the repo root.

| # | Where | Command |
|---|---|---|
| 1 | VS Code / terminal | `python Python/prepare_stimulus.py` |
| 2 | Vivado Tcl console | `cd {C:/Users/Xps/Desktop/CNN_Accelerator}` then `source Scripts/run_simulation.tcl` |
| 3 | VS Code / terminal | `python Python/mem_to_image.py` |

That's it — step 2 also runs `Python/verify.py` internally through the
testbench flow and prints PASS/FAIL to the Tcl console.

**No Vivado handy right now?** Use the open-source fast path instead of
step 2 (same RTL, same testbench, same golden model — just a different
simulator):

```bash
bash Scripts/run_simulation_iverilog.sh
```

### First-time setup

```bash
git clone <this-repo-url> CNN_Accelerator
cd CNN_Accelerator
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Then open `Vivado/CNN_Accelerator.xpr` directly in Vivado (it's tracked in
this repo — no need to run `Scripts/build.tcl` first). If you ever need to
recreate it from scratch: `vivado -mode batch -source Scripts/build.tcl`.

**Required software:** Xilinx Vivado (7-series/UltraScale part), Python
3.10+ (NumPy, OpenCV, Matplotlib — see `requirements.txt`), VS Code, Git.
Optional: Icarus Verilog + GTKWave for the no-Vivado fast path.

## 3. How it works

```
Python (prepare_stimulus.py):
  input.png --resize+quantize--> [32x32 array] --+--> input_image.mem
                                                   +--> input_32x32_preview.png
                                  (also writes kernels/edge_3x3.mem, the vertical-Sobel kernel)

RTL (Vivado, run_simulation.tcl):
  input_image.mem + kernels/edge_3x3.mem --> sim/rtl_output.mem

Python (mem_to_image.py):
  sim/rtl_output.mem --> rtl_output_preview.png
```

`Scripts/run_simulation.tcl` also calls `Python/verify.py`, which
recomputes the same convolution in NumPy and diffs it element-by-element
against `sim/rtl_output.mem` for an automatic PASS/FAIL.

## 4. Accelerator architecture

```
kernel load ──▶ kernel_memory.v                    controller.v (FSM)
                                                    drives raster-scan
image stream ──▶ image_memory.v ──▶ line_buffer.v ──▶ window_generator.v
                (row-major read)   (K-1 row delay)   (assembles KxK window)
                                                              │
                                                              ▼
                                                           mac.v
                                                   (multiply-accumulate)
                                                              │
                                                              ▼
                                                     output_buffer.v
                                              (optional ReLU, FIFO stream out)
```

`top.v` wires all of the above together and aligns pipeline latency so the
"valid window" tag stays in lockstep with the data. Full detail:
`Documentation/Architecture.md`.

## 5. Folder structure

```
CNN_Accelerator/
├── RTL/            Verilog datapath + control (top.v, controller.v, mac.v, ...)
├── Testbench/       Verilog unit + system testbenches
├── Python/          Golden model, image tooling, verification scripts
├── Images/          Test images, preview PNGs, programmable kernels
├── Vivado/          Vivado project (tracked) + constraints
├── Scripts/         Tcl build/simulate/synthesize + Icarus fast path
├── Reports/         synthesis/ timing/ utilization/ power/ (filled at Phase 11-13)
├── Presentation/    Final competition slide deck (filled at Phase 14)
├── Documentation/   Architecture, roadmap, requirements, file guide
├── .gitignore, README.md, requirements.txt, LICENSE
```

Per-file purpose/responsibility: `Documentation/FileGuide.md`.

## 6. Naming convention

Every signal, port, parameter, and Python variable in this project follows
one rule: multi-word names are written `First_Second` (each word's first
letter capitalized, words joined by `_`, never abbreviated mid-word).
Module/function/file names are kept as-is, since Verilog module names are
referenced directly inside `Vivado/CNN_Accelerator.xpr` — renaming them
would require hand-editing the Vivado project file itself.

## 7. Verification flow

```
Input Image ──▶ Python Golden Model (golden_model.py) ──▶ Expected Output
                                                                  │
RTL Simulation (Testbench/tb_top.v) ──▶ RTL Output ──▶ Compare (verify.py) ──▶ PASS/FAIL
```

Current result (see `Documentation/VerificationResults.md` for full detail):

| Testbench | Result |
|---|---|
| `tb_mac.v` | 3/3 hand-computed vectors passed |
| `tb_controller.v` | address sequencing + valid-window count exact |
| `tb_top.v` | **900/900 outputs bit-exact** vs. the golden model (32x32 image, 3x3 kernel) |

## 8. Synthesis flow (Phases 11-13, on your machine)

1. `vivado -mode batch -source Scripts/synthesize.tcl` — placeholder today,
   completed once RTL timing/resource tuning (Phase 10) is done.
2. Reports export to `Reports/utilization/`, `Reports/timing/`, `Reports/power/`.
3. Manual alternative: Vivado GUI → Run Synthesis → Run Implementation →
   Report Utilization / Timing Summary / Power → export into the matching
   `Reports/` subfolder.

## 9. Competition requirements checklist

Sourced from `2026 SSCS_Egypt Competition Announcement.pdf` (IEEE SSCS
Egypt Chapter, registration deadline **July 25, 2026**, report due
**September 15, 2026**).

| # | Required specification | Status | Where |
|---|---|---|---|
| 1 | Min. 32x32 grayscale image/feature map input | ✅ Met | `Img_W`/`Img_H` = 32 in `RTL/image_memory.v`, `RTL/top.v` (parameterizable, larger sizes supported) |
| 2 | Input precision: unsigned fixed-point | ✅ Met | `Pixel_W`-bit unsigned datapath throughout |
| 3 | Programmable/configurable NxN kernel | ✅ Met | `RTL/kernel_memory.v`, runtime-writable via `Kernel_We`/`Kernel_Windex` |
| 4 | Kernel precision: 8-bit signed | ✅ Met | `Kernel_W = 8`, signed, `RTL/kernel_memory.v` |
| 5 | Stride = 1 | ✅ Met | `RTL/window_generator.v` shifts one pixel/cycle |
| 6 | Output precision: min. 16-bit signed | ✅ Met | `Acc_W = 20` signed in `RTL/mac.v` / `RTL/output_buffer.v` (saturating) |
| 7 | ReLU activation (bonus) | ✅ Met | `Relu_En` control bit, applied in `RTL/output_buffer.v` |
| 8 | Verified against a Python/MATLAB/C golden model | ✅ Met | `Python/golden_model.py` + `Python/verify.py`, 900/900 bit-exact (§7 above) |
| 9 | FPGA synthesis + implementation results (LUTs, FFs, DSPs, BRAMs, Fmax, timing, power) | ⏳ Pending | Needs a Vivado run on your machine — `Reports/{utilization,timing,power}/` are scaffolded but empty; see §8 |
| 10 | Figure of Merit (Throughput / (Power × (LUTs + 50·DSPs + 100·BRAMs))) | ⏳ Pending | Computed once #9 is available — `Documentation/DevelopmentRoadmap.md` Phase 14 |

**Deliverables checklist** (report, RTL, testbench, golden model, test
images, expected outputs, FPGA reports, short presentation):

| Deliverable | Status |
|---|---|
| Architecture / block diagram / FSM / memory organization write-up | ✅ Done — `Documentation/Architecture.md` |
| RTL source + testbench + golden model | ✅ Done — `RTL/`, `Testbench/`, `Python/` |
| Test images + expected outputs | ✅ Done — `Images/` |
| Waveform screenshots | ⏳ Take from `Vivado/tb_top_waves.wcfg` once you run §2 step 2 |
| FPGA synthesis/timing/power reports | ⏳ Pending Vivado run (§8) |
| Report Table 1 (Parameter/Specification/Team Result/Units/Comments) | ⏳ Fill in once #9/#10 are available |
| Short presentation | ⏳ Pending — `Presentation/` |

## 10. Development roadmap

| Phase | Status | Name |
|---|---|---|
| 1-9 | ✅ Done | Setup → Golden model → Memory/Line buffer/Window/MAC/Controller/Top → Simulation |
| 10 | ⏳ Todo | Optimization (pipelining, BRAM line buffer) |
| 11 | ⏳ Todo | Synthesis |
| 12 | ⏳ Todo | Timing closure |
| 13 | ⏳ Todo | Power optimization |
| 14 | ⏳ Todo | Final report / Figure of Merit |

Full detail: `Documentation/DevelopmentRoadmap.md`.

## 11. License

See `LICENSE`.

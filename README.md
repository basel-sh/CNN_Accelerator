# CNN Convolution Accelerator

FPGA-based edge-AI `K x K` convolution accelerator, built for the **IEEE SSCS Egypt
Chapter 2026 Student Design Competition**. Programmable kernel, unsigned pixel input,
signed 8-bit kernel, stride 1, optional ReLU — verified bit-exact against a Python
golden model before any synthesis number is trusted.

> **Status: done.** One design, fully implemented, timing-closed, and reported:
> 2 output pixels/cycle, zero DSPs, single 20 MHz clock. **Figure of Merit: 1.10e-2.**
> An earlier 1-pixel/cycle baseline and a 4-DSP/second-clock-domain variant were both
> explored and then removed from the repo once this design replaced them — their
> reasoning is kept in `Documentation/OptimizationLog.md` and
> `Documentation/Aggressive2px.md`.

---

## 1. What this is

A programmable convolution accelerator for grayscale images / CNN feature maps,
targeting a Xilinx 7-series FPGA (`xc7a35tcpg236-1`):

- Unsigned fixed-point input pixels, signed 8-bit programmable kernel coefficients
- Stride = 1, optional ReLU
- Signed >=16-bit accumulator/output (20-bit, sized for the worst-case 3x3/8-bit sum)
- **2 output pixels/cycle**, zero DSP slices, single clock domain

## 2. Result — Figure of Merit

`FoM = Throughput / (Power x (LUT + 50*DSP + 100*BRAM))`, Throughput in output
pixels/cycle. Full derivation: `Documentation/PerformanceResults.md`; full history
of how this design was reached: `Reports/README.md`.

| Throughput | LUT | FF | DSP | BRAM | Power (W) | WNS (ns) | FoM |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 px/cycle | 1411 | 638 | 0 | 1.0 | 0.120 | **+35.076 (PASS)** | **1.10e-2** |

It gets both outputs/cycle by running all 18 products (9 per output window) through
fabric multipliers on the same 20 MHz clock as everything else — no DSPs, no second
clock domain, no clock-domain-crossing logic. An earlier attempt shared 4 DSP48s over
a 120 MHz second clock instead; it worked in simulation but never closed timing
(WNS -4.338 ns), so it was abandoned. That trail is documented, not deleted, in
`Documentation/Aggressive2px.md`.

## 3. Quick start

Three steps, three tools, from the repo root.

| # | Where | Command |
|---|---|---|
| 1 | terminal | `python Python/prepare_stimulus.py` |
| 2 | Vivado Tcl console | `cd {C:/Users/Xps/Desktop/CNN_Accelerator}` then `source Scripts/run_simulation_2px.tcl` |
| 3 | terminal | `python Python/verify.py --image Images/input_32x32.mem --kernel Images/kernels/edge_3x3.mem --rtl-output sim/rtl_output_2px.mem --img-size 32 32 --k 3 --acc-width 20` |

Look for `Compared 900 output values.` and `RESULT: PASS`.

### First-time setup

```bash
git clone https://github.com/basel-sh/CNN_Accelerator.git
cd CNN_Accelerator
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

`Vivado_2px/CNN_Accelerator_2px.xpr` is tracked in the repo, so just open it in
Vivado — no need to run `Scripts/build_2px.tcl` first. If you ever need to
recreate it from scratch: `vivado -mode batch -source Scripts/build_2px.tcl`.

**Required:** Xilinx Vivado (7-series), Python 3.10+ (NumPy, OpenCV, Matplotlib —
`requirements.txt`), VS Code, Git.

## 4. Command reference — everything I actually run

### Python / terminal

| Command | What it does |
|---|---|
| `python Python/prepare_stimulus.py` | Resizes/quantizes `Images/input.png` to 32x32, writes `Images/input_32x32.mem` + a preview PNG, and writes the demo kernel to `Images/kernels/edge_3x3.mem` |
| `python Python/verify.py --image Images/input_32x32.mem --kernel Images/kernels/edge_3x3.mem --rtl-output sim/rtl_output_2px.mem --img-size 32 32 --k 3 --acc-width 20` | Compares RTL sim output to the golden model, element by element |
| same, with `--kernel Images/kernels/random_3x3_test2.mem` | Second-kernel regression (see step below — needs a testbench edit first) |
| same, with `--relu` added | ReLU-on regression |
| `python Python/mem_to_image.py` | Turns RTL output back into a viewable PNG. **Still hardcoded to `sim/rtl_output.mem`** — copy `sim/rtl_output_2px.mem` over that path first (`copy sim\rtl_output_2px.mem sim\rtl_output.mem` on Windows) |

### Vivado Tcl console

Always `cd {C:/Users/Xps/Desktop/CNN_Accelerator}` first if the console doesn't
already sit at the repo root.

| Command | What it does |
|---|---|
| `source Scripts/run_simulation_2px.tcl` | Behavioral sim of `top_2px.v`, writes `sim/rtl_output_2px.mem` |
| `source Scripts/synthesize_2px.tcl` | Full synth + routed implementation, exports to `Reports/` |

**The habit that matters most:** always run `run_simulation_2px.tcl` and confirm
`900 output values` / `RESULT: PASS` **before** running `synthesize_2px.tcl`. A
synthesis run that isn't backed by a fresh PASS wastes 20+ minutes if the RTL
changed since the last verified sim.

### Testing the second kernel / ReLU (not yet done for this design — see below)

Both are written into the repo but haven't been run through `top_2px.v` yet:

```
# 1. Edit Testbench/tb_top_2px.v, change the kernel readmemh line to:
$readmemh("Images/kernels/random_3x3_test2.mem", Kernel_Stim);

# 2. Re-run:
source Scripts/run_simulation_2px.tcl

# 3. Verify against the matching kernel:
python Python/verify.py --image Images/input_32x32.mem --kernel Images/kernels/random_3x3_test2.mem --rtl-output sim/rtl_output_2px.mem --img-size 32 32 --k 3 --acc-width 20

# 4. Revert the readmemh line back to edge_3x3.mem when done.
```

For ReLU, before sourcing the sim script:
```tcl
set_property -name {xsim.simulate.xsim.more_options} -value {-testplusarg RELU=1} -objects [get_filesets sim_1]
source Scripts/run_simulation_2px.tcl
```
then add `--relu` to the `verify.py` call, and reset the property to `{}`
afterward. See `Documentation/DevelopmentRoadmap.md` phase 15.

## 5. How it works

```
Python (prepare_stimulus.py):
  input.png --resize+quantize--> [32x32 array] --+--> input_32x32.mem
                                                   +--> input_32x32_preview.png
                                  (also writes kernels/edge_3x3.mem, vertical-Sobel)

RTL (Vivado, run_simulation_2px.tcl):
  input_32x32.mem + kernels/edge_3x3.mem --> sim/rtl_output_2px.mem

Python (mem_to_image.py):
  sim/rtl_output_2px.mem --> rtl_output_preview.png
```

## 6. Accelerator architecture

```
kernel load ──▶ kernel_memory.v                     controller_2px.v (FSM)
                                                      drives raster-scan, 2 px/cycle
image stream ──▶ image_memory_2px.v ──▶ line_buffer_2px.v ──▶ window_generator_2px.v
              (dual read port)        (K-1 row delay,         (2 overlapping KxK
                                        both lanes)             windows/cycle)
                                                                        │
                                                                        ▼
                                                                   mac_pair.v
                                                        (18 fabric multiplies, balanced
                                                         adder tree x2, zero DSP)
                                                                        │
                                                                        ▼
                                                              top_2px.v output
                                                       (ReLU inline, 2 lanes/cycle)
```

`top_2px.v` wires all of the above together and aligns pipeline latency so the
valid-window tag stays in lockstep with the data. Full detail:
`Documentation/Architecture.md`.

## 7. Folder structure

```
CNN_Accelerator/
├── RTL/              Verilog: top_2px.v + submodules (single design)
├── Testbench/         tb_top_2px.v
├── Python/            Golden model, image tooling, verification script
├── Images/            Test images, preview PNGs, programmable kernels
├── Vivado_2px/         Vivado project + constraints
├── Scripts/           Tcl build/simulate/synthesize scripts
├── Reports/           utilization/timing/power for the current design
├── Presentation/      Competition slide deck
├── Documentation/     Architecture, roadmap, requirements, design history
├── .gitignore, README.md, requirements.txt, LICENSE
```

Per-file purpose: `Documentation/FileGuide.md`.

## 8. Naming convention

Every signal, port, parameter, and Python variable follows one rule: multi-word
names are written `First_Second` (each word capitalized, joined by `_`, never
abbreviated mid-word). Module/function/file names are kept as-is, since Verilog
module names are referenced directly inside `Vivado_2px/CNN_Accelerator_2px.xpr` —
renaming them would mean hand-editing that project file without a way to verify
the result here. (That's also why the project folder and module names still carry
a `_2px` suffix even though this is the only design in the repo now — cosmetic,
not functional.)

## 9. Verification

```
Input Image ──▶ Python Golden Model (golden_model.py) ──▶ Expected Output
                                                                  │
RTL Simulation (Testbench/tb_top_2px.v) ──▶ RTL Output ──▶ Compare (verify.py) ──▶ PASS/FAIL
```

| Case | Result |
|---|---|
| Demo kernel (`edge_3x3.mem`), ReLU off | **900/900 outputs bit-exact** vs. the golden model |
| Second kernel (`random_3x3_test2.mem`) | not yet run through this design — see §4 |
| ReLU on | not yet run through this design — see §4 |

Full detail: `Documentation/VerificationResults.md`.

## 10. Competition requirements checklist

Source: `2026 SSCS_Egypt Competition Announcement.pdf` (repo root). Report due
**September 15, 2026**.

| # | Requirement | Status |
|---|---|---|
| 1 | Min. 32x32 grayscale image/feature map input | Done |
| 2 | Input precision: unsigned fixed-point | Done |
| 3 | Programmable NxN kernel | Done |
| 4 | Kernel precision: 8-bit signed | Done |
| 5 | Stride = 1 | Done |
| 6 | Output precision: min. 16-bit signed | Done (20-bit) |
| 7 | ReLU activation (bonus) | Done in RTL — regression against it still pending, see §4 |
| 8 | Verified against a golden model | Done for the demo case; second kernel pending |
| 9 | Synthesis/implementation results | Done — `Reports/` |
| 10 | Figure of Merit | Done — 1.10e-2 |

## 11. Timeline

- **Late July 2026** — Project scaffolding: folder structure, Python golden model,
  kernel test files, initial RTL skeleton.
- **September 5** — First working 1-pixel/cycle design close to competition-ready.
  Killed an oversized 1024-deep output FIFO that was synthesizing as ~20,000 flip-flops
  (it was sized for a full frame of results when the testbench only ever needed a couple
  entries of slack), dropped the placeholder 100 MHz clock to 20 MHz (the FoM's Throughput
  term is cycles-based, so a slower clock only helps the Power term), and fixed two
  reset-hazard DRC violations on BlockRAM control pins. Result: LUT 7396 -> 842,
  FF 20966 -> 758, FoM 3.96e-4 -> 7.52e-3 (~19x). Full log:
  `Documentation/OptimizationLog.md`.
- **September 6** — Explored real-board integration for that 1px design: an AXI4-Lite
  wrapper (`axi_top_wrapper.v`) around it and a Zynq PS7 block design, plus scripts to
  drop the PS7 clock for extra power savings. This never became part of the reported
  FoM and was removed along with the 1px baseline once the 2px design replaced it.
- **September 10** — Built the full 2-pixel/cycle front end (`controller_2px.v`,
  `image_memory_2px.v`, `line_buffer_2px.v`, `window_generator_2px.v`) and two
  competing MAC engines behind it: `mac_pair.v` (18 fabric multiplies, zero DSP, one
  clock) and `mac_pair_mp4.v` (4 shared DSP48s time-multiplexed over a second,
  120 MHz clock, needing async CDC FIFOs to get requests/results across). The DSP
  version was simulated first and passed functionally, 900/900.
- **September 11, morning** — Synthesized the 4-DSP version: it never closed timing
  (WNS -4.338 ns on the 120 MHz domain — the DSP-output accumulation path plus the
  CDC logic didn't fit in 8.333 ns), and FF ballooned to 1286 from the Gray-code
  CDC pointer logic it needed. Its FoM (8.27e-3) was only ever provisional and never
  a valid, reportable number.
- **September 11, afternoon** — Synthesized `top_2px.v` + `mac_pair.v` instead: same
  20 MHz clock as the 1px baseline, no DSPs, no second clock domain, no CDC logic —
  just 18 products done fully in parallel in fabric. It closed timing at +35.076 ns,
  the first real 2px/cycle result in this project. FoM: **1.10e-2**, +46.6% over the
  1px baseline. Adopted as the final design.
- **September 11, evening** — Repo cleanup: removed the 1px baseline (`RTL/top.v` and
  its dependents, the `Vivado/` project folder), the AXI/board-bringup path, and the
  abandoned 4-DSP attempt (`mac_pair_mp4.v`/`mac_pair_mp3.v`, the `Vivado_2px_MP4/`
  project folder) entirely. **`Vivado_2px/` is now the only Vivado project folder in
  the repo.** Reports consolidated from three separate folders into one
  `Reports/{utilization,timing,power}/`. The reasoning behind every removed design is
  kept, not deleted, in `Documentation/OptimizationLog.md` and
  `Documentation/Aggressive2px.md`.

## 12. License

See `LICENSE`.

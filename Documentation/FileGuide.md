# File Guide — Why Every File Exists

This document explains, for every file/folder in the project, why it exists,
its responsibility, and which files it interacts with. The repo holds a
single design now — the 2 output-pixels/cycle, zero-DSP accelerator — after
an earlier 1-pixel/cycle baseline and an abandoned 4-DSP variant were removed.
Both are still described, for the record, in `Documentation/OptimizationLog.md`
and `Documentation/Aggressive2px.md`.

## RTL/

| File | Why it exists | Responsibility | Interacts with |
|---|---|---|---|
| `top_2px.v` | Single entry point the FPGA (and testbench) instantiates | Wire together every submodule into the complete accelerator, apply ReLU | all RTL modules below, `Testbench/tb_top_2px.v`, `Vivado_2px/constraints_2px.xdc` |
| `controller_2px.v` | Convolution needs a sequencer; without one, memories/datapath don't know when to act | FSM for kernel load, image streaming (2 px/cycle addressing), pair-valid handshake | `top_2px.v`, `image_memory_2px.v`, `line_buffer_2px.v`, `window_generator_2px.v` |
| `mac_pair.v` | The actual convolution arithmetic, sized for 2 outputs/cycle with zero DSPs | 18 fabric multiplies (2x9), registered products, balanced adder tree per lane | `window_generator_2px.v`, `kernel_memory.v`, `top_2px.v` |
| `line_buffer_2px.v` | Sliding-window convolution over a streamed image needs row history without re-fetching memory, doubled for two pixel lanes | Store K-1 previous rows for both lanes | `image_memory_2px.v`, `window_generator_2px.v` |
| `window_generator_2px.v` | Bridges streamed pixel pairs + line buffer taps into the two overlapping KxK windows `mac_pair.v` needs | Assemble/shift two KxK windows at stride 1, one column apart | `line_buffer_2px.v`, `mac_pair.v`, `controller_2px.v` |
| `kernel_memory.v` | Kernel must be programmable, not hard-coded, per competition spec | Store/serve signed 8-bit KxK coefficients, support reload | `top_2px.v`, `controller_2px.v`, `mac_pair.v` |
| `image_memory_2px.v` | Input image (>=32x32) must be staged and streamed two pixels/cycle | Store the frame in one dual-read-port Block RAM | `top_2px.v`, `controller_2px.v`, `line_buffer_2px.v` |

Everything else that used to live in `RTL/` — `top.v`, `mac.v`, `controller.v`,
`image_memory.v`, `line_buffer.v`, `window_generator.v`, `output_buffer.v`,
`ram.v`, `fifo.v` (the 1px baseline), `top_2px_mp4.v`, `mac_pair_mp4.v`,
`mac_pair_mp3.v`, `mac_pair_mp3_fixed.v`, `clock_5x.v` (the abandoned 4-DSP
variant), and `axi_top_wrapper.v` (an unfinished Zynq/AXI board-bringup
wrapper for the old baseline) — has been removed. Their reasoning is preserved
in `Documentation/OptimizationLog.md` and `Documentation/Aggressive2px.md`.

## Testbench/

| File | Why it exists | Responsibility | Interacts with |
|---|---|---|---|
| `tb_top_2px.v` | End-to-end correctness can only be proven at the system level | Drive `top_2px.v` with golden-model stimulus, dump both result lanes in raster order, optional `-testplusarg RELU=1` | `RTL/top_2px.v`, `Python/verify.py`, `Images/` |

The old `tb_top.v`, `tb_controller.v`, `tb_mac.v` (unit tests for the removed
baseline modules) and the `Testbench/sv/` UVM-style environment (built around
the removed `top`/`controller.v`) are gone along with the modules they tested.

## Python/

| File | Why it exists | Responsibility | Interacts with |
|---|---|---|---|
| `golden_model.py` | Competition requires golden-model verification | Bit-accurate reference convolution | `convolution.py`, `image_loader.py`, `verify.py` |
| `convolution.py` | Keeps generic conv math separate from the bit-accurate model | Reusable convolution helpers (NumPy reference) | `golden_model.py` |
| `image_loader.py` | RTL and Python must consume/produce the exact same data | Load/quantize images, write RTL-readable stimulus files | `Images/`, `golden_model.py`, `Testbench/tb_top_2px.v` |
| `image_generator.py` | Real-world images alone won't cover corner cases required for a rigorous FoM | Synthetic test images/kernels | `Images/`, `golden_model.py`, `verify.py` |
| `verify.py` | Someone/something must issue the final PASS/FAIL | Compare golden vs RTL output automatically | `golden_model.py`, `sim/rtl_output.mem` |
| `prepare_stimulus.py` | One command should produce ready-to-simulate stimulus | Resize/quantize `input.png`, write the kernel coefficient array | `Images/` |
| `mem_to_image.py` | A numeric PASS isn't the same as "looks right" | Turn RTL output back into a viewable PNG | `sim/rtl_output.mem` |
| `utilities.py` | Avoids duplicating quantize/plot helpers across scripts | Shared fixed-point + Matplotlib helpers | all other `Python/` files |

`tb_top_2px.v` and `mem_to_image.py` both now use `sim/rtl_output.mem` — they
used to disagree (`_2px` suffix vs. not), which meant copying the file
manually before every visual check. To test a different kernel, edit the
coefficient array near the bottom of `prepare_stimulus.py` and re-run it —
it overwrites `Images/kernels/edge_3x3.mem`, the one filename the testbench
ever reads, rather than adding a second kernel file.

## Images/

| Item | Why it exists | Responsibility |
|---|---|---|
| `input.png` | A concrete, versioned test input everyone (Python + RTL) uses | Sample >=32x32 grayscale source image |
| `input_32x32.mem` / `input_32x32_preview.png` | RTL and Python must consume/produce byte-identical stimulus | `$readmemh` hex export + human-viewable preview of `input.png` |
| `rtl_output_preview.png` | Visual sanity check alongside the numeric PASS/FAIL | RTL output rendered as an image |
| `kernels/` | Kernel is programmable — multiple kernels must be tested | Holds the one `edge_3x3.mem` coefficient file the testbench reads; a different kernel means overwriting its contents via `prepare_stimulus.py`, not adding a second file |

## Reports/

`utilization/`, `timing/`, `power/` hold the routed implementation reports for
the current (and only) design, exported by `Scripts/synthesize_2px.tcl`. See
`Reports/README.md` for the final numbers.

## Vivado_2px/

| File | Why it exists | Responsibility |
|---|---|---|
| `CNN_Accelerator_2px.xpr` | Vivado's own project file — tracked in Git so a fresh clone opens directly | Regenerable via `Scripts/build_2px.tcl` if ever deleted |
| `constraints_2px.xdc` | Timing closure requires constraints | Single 20 MHz clock definition, I/O delays, false path on `Rst_N` |

The project/folder keeps its `_2px` name rather than being renamed to
`Vivado`/`CNN_Accelerator.xpr` — Verilog module names and file paths are
referenced directly inside the `.xpr` project XML, and there's no way to
validate a rename here without Vivado open. It's a cosmetic mismatch, not a
functional one: this is the only Vivado project in the repo.

## Documentation/

| File | Why it exists | Responsibility |
|---|---|---|
| `Architecture.md` | Design decisions must be written down | High-level architecture, dataflow, FSM, memory hierarchy of the current design |
| `DevelopmentRoadmap.md` | An explicit, ordered project plan | Phase-by-phase goals and file ownership |
| `CompetitionRequirements.md` | Every scored requirement must be traceable to a design element | Requirement-to-file mapping |
| `PerformanceResults.md` | The FoM and its inputs must be computed and justified once, correctly | Fmax, FoM, precision justification |
| `VerificationResults.md` | Correctness claims need evidence, not just "it passed" | Testbench results, bugs found and fixed |
| `OptimizationLog.md` | How the baseline went from unusable to competitive is worth keeping | 1px-baseline optimization history (baseline itself now removed) |
| `Aggressive2px.md` | How the final 2px design was chosen over the DSP-sharing alternative is worth keeping | 2px design-space exploration, including the abandoned 4-DSP attempt |
| `FileGuide.md` | This file — nothing in the tree should be a mystery | Explains every file's purpose/responsibility/interactions |

## Scripts/

| File | Why it exists | Responsibility | Interacts with |
|---|---|---|---|
| `build_2px.tcl` | Vivado project creation must be reproducible, not manual-only | Creates/refreshes `CNN_Accelerator_2px.xpr`, adds RTL/testbench/constraints sources | `RTL/`, `Testbench/`, `Vivado_2px/constraints_2px.xdc` |
| `run_simulation_2px.tcl` | Simulation must be scriptable/repeatable | Launches XSim, runs `tb_top_2px.v`, dumps `sim/rtl_output.mem` | `Testbench/`, `Python/verify.py` |
| `synthesize_2px.tcl` | Synthesis/implementation/report export must be scriptable | Runs synth/impl, exports timing/utilization/power reports | `Vivado_2px/`, `Reports/` |
| `run_simulation_iverilog.sh` | Removed — it compiled the old baseline's file list only (`RTL/ram.v`, `mac.v`, `top.v`, ...), none of which exist anymore | n/a | n/a |

Everything else that used to live in `Scripts/` — `build.tcl`,
`run_simulation.tcl`, `synthesize.tcl` (the 1px baseline), `build_2px_mp4.tcl`,
`run_simulation_2px_mp4.tcl`, `synthesize_2px_mp4.tcl` (the abandoned 4-DSP
variant), and `build_axi_bd.tcl`/`lower_apu_clk.tcl`/`lower_fclk.tcl`/
`optimize_design.tcl`/`write_bitstream_pre.tcl` (an unfinished Zynq board
bring-up path for the old baseline) — has been removed along with the design
they targeted.

## Root files

| File | Why it exists | Responsibility |
|---|---|---|
| `.gitignore` | Keeps generated/large/machine-specific files out of Git | Excludes Vivado build artifacts, sim waveforms, `__pycache__`, etc. |
| `README.md` | First thing anyone (teammate, judge) reads | Overview, setup, build/sim/verify/synth flow, command reference |
| `requirements.txt` | Python environment must be reproducible | Pinned dependency versions |
| `LICENSE` | Public GitHub repos should state usage terms | Project license |

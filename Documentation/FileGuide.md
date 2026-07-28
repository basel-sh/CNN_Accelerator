# File Guide — Why Every File Exists

This document explains, for every file/folder in the project, why it exists,
its responsibility, and which files it interacts with. Nothing in the tree
is unexplained. Status: RTL/Testbench/Python (Phases 1-9) are implemented;
Vivado/Reports/Presentation content (Phases 10-14) is generated on your
machine — see root `README.md`.

## RTL/

| File | Why it exists | Responsibility | Implemented later | Interacts with |
|---|---|---|---|---|
| `top.v` | Single entry point the FPGA (and testbench) instantiates | Wire together every submodule into the complete accelerator | Port list, module instantiations, top-level handshake | all RTL modules, `Testbench/tb_top.v`, `Vivado/constraints.xdc` |
| `controller.v` | Convolution needs a sequencer; without one, memories/datapath don't know when to act | FSM for kernel load, image streaming, ReLU enable, output handshake | States listed in `Architecture.md` §5 | `top.v`, memories, line buffer, window generator, mac, output buffer |
| `mac.v` | The actual convolution arithmetic must live somewhere reusable/testable in isolation | Signed x unsigned multiply, accumulate to signed >=16-bit | Multiplier, accumulator register, overflow handling | `window_generator.v`, `kernel_memory.v`, `controller.v`, `tb_mac.v` |
| `line_buffer.v` | Sliding-window convolution over a streamed image needs row history without re-fetching memory | Store N-1 previous rows | Row-shifting registers/FIFOs, sized by N | `image_memory.v`, `window_generator.v`, `fifo.v`, `ram.v` |
| `window_generator.v` | Bridges streamed pixels + line buffer taps into the NxN window the MAC needs | Assemble/shift the NxN window at stride 1 | Horizontal shift registers per row | `line_buffer.v`, `mac.v`, `controller.v` |
| `kernel_memory.v` | Kernel must be programmable, not hard-coded, per competition spec | Store/serve signed 8-bit NxN coefficients, support reload | Write interface, coefficient array | `top.v`, `controller.v`, `mac.v`, `ram.v` |
| `image_memory.v` | Input image (>=32x32) must be staged and streamed in a controlled order | Store/serve unsigned fixed-point pixels | Address generation, read port | `top.v`, `controller.v`, `line_buffer.v`, `ram.v` |
| `output_buffer.v` | Decouples MAC production timing from output consumption; hosts optional ReLU | Buffer/stream results, optional ReLU clamp | FIFO instantiation, ReLU logic | `mac.v`, `controller.v`, `top.v`, `fifo.v` |
| `ram.v` | Every memory module needs a common, synthesis-friendly storage primitive | Generic parameterizable sync RAM | Port width/depth params, BRAM inference pattern | `image_memory.v`, `kernel_memory.v`, `line_buffer.v` |
| `fifo.v` | Elastic buffering is needed in more than one place (line buffer, output) | Generic parameterizable sync FIFO | Read/write pointers, full/empty flags | `line_buffer.v`, `output_buffer.v` |

## Testbench/

| File | Why it exists | Responsibility | Implemented later | Interacts with |
|---|---|---|---|---|
| `tb_top.v` | End-to-end correctness can only be proven at the system level | Drive `top.v` with golden-model stimulus, dump RTL output | Stimulus loading, clock/reset gen, result dump | `RTL/top.v`, `Python/verify.py`, `Images/` |
| `tb_controller.v` | FSM bugs are easiest to isolate without the full datapath attached | Verify FSM transitions/timing standalone | State-checking assertions | `RTL/controller.v` |
| `tb_mac.v` | Arithmetic correctness (signedness, width, rounding) must be nailed down before integration | Verify MAC math against reference vectors | Reference vector application/checking | `RTL/mac.v`, `Python/golden_model.py` |

## Python/

| File | Why it exists | Responsibility | Implemented later | Interacts with |
|---|---|---|---|---|
| `golden_model.py` | Competition requires golden-model verification | Bit-accurate reference convolution | Quantization-matched convolution routine | `convolution.py`, `image_loader.py`, `verify.py` |
| `convolution.py` | Keeps generic conv math separate from the bit-accurate model | Reusable convolution helpers (e.g. NumPy reference) | `convolve2d` and stride/padding helpers | `golden_model.py` |
| `image_loader.py` | RTL and Python must consume/produce the exact same data | Load/quantize images, write RTL-readable stimulus files | OpenCV load, quantize, `$readmemh` export | `Images/`, `golden_model.py`, `Testbench/tb_top.v` |
| `image_generator.py` | Real-world images alone won't cover corner cases required for a rigorous FoM | Synthetic test images/kernels (edge cases) | Pattern + kernel generators | `Images/`, `golden_model.py`, `verify.py` |
| `verify.py` | Someone/something must issue the final PASS/FAIL | Compare golden vs RTL output automatically | Parsing + comparison + reporting | `golden_model.py`, `Testbench/tb_top.v` output, `Scripts/run_simulation.tcl` |
| `utilities.py` | Avoids duplicating quantize/plot helpers across scripts | Shared fixed-point + Matplotlib helpers | `quantize()`, `plot_image()` | all other Python/ files |

## Images/

| Item | Why it exists | Responsibility |
|---|---|---|
| `input.png` | A concrete, versioned test input everyone (Python + RTL) uses | Sample >=32x32 grayscale source image |
| `input_32x32.mem` / `input_32x32_preview.png` | RTL and Python must consume/produce byte-identical stimulus | `$readmemh` hex export + human-viewable preview of `input.png` |
| `rtl_output_preview.png` | Visual sanity check alongside the numeric PASS/FAIL | `sim/rtl_output.mem` rendered as an image |
| `kernels/` | Kernel is programmable — multiple kernels must be tested | Holds the NxN signed-8-bit coefficient sets |

## Reports/

`synthesis/`, `timing/`, `utilization/`, `power/` each exist because the
competition explicitly requires synthesis, timing, and power reports, plus
utilization is a named scoring criterion — separating them avoids one messy
folder and matches how the reports are exported from Vivado (Phases 11-13).

## Vivado/

| File | Why it exists | Responsibility |
|---|---|---|
| `CNN_Accelerator.xpr` | Vivado's own project file — tracked in Git so a fresh clone opens directly | Regenerable via `Scripts/build.tcl` if ever deleted |
| `constraints.xdc` | Timing closure and correct board I/O require constraints | Clock definition, pin assignments, exceptions |
| `tb_top_waves.wcfg` | A useful default waveform layout should open automatically | Saved/refreshed each `Scripts/run_simulation.tcl` run |

## Presentation/

Holds the final competition deliverable (slides, diagrams, result plots),
kept separate from technical `Reports/` because it's a curated summary, not
raw tool output.

## Documentation/

| File | Why it exists | Responsibility |
|---|---|---|
| `Architecture.md` | Design decisions must be written down before coding starts | High-level architecture, dataflow, FSM, memory hierarchy |
| `DevelopmentRoadmap.md` | A 14-phase project needs an explicit, ordered plan | Phase-by-phase goals and file ownership |
| `CompetitionRequirements.md` | Every scored requirement must be traceable to a design element | Requirement-to-file/phase mapping |
| `FileGuide.md` | This file — nothing in the tree should be a mystery | Explains every file's purpose/responsibility/interactions |

## Scripts/

| File | Why it exists | Responsibility | Interacts with |
|---|---|---|---|
| `build.tcl` | Vivado project creation must be reproducible, not manual-only | Creates/refreshes `CNN_Accelerator.xpr`, adds RTL/testbench/constraints sources | `RTL/`, `Testbench/`, `Vivado/constraints.xdc` |
| `run_simulation.tcl` | Simulation must be scriptable/repeatable (batch or CI) | Launches simulator, runs `tb_top.v`, dumps results | `Testbench/`, `Python/verify.py` |
| `synthesize.tcl` | Synthesis/implementation/report export must be scriptable | Runs synth/impl, exports timing/utilization/power reports | `Vivado/`, `Reports/` |

## Root files

| File | Why it exists | Responsibility |
|---|---|---|
| `.gitignore` | Keeps generated/large/machine-specific files out of Git | Excludes Vivado build artifacts, sim waveforms, `__pycache__`, etc. |
| `README.md` | First thing anyone (teammate, judge) reads | Overview, setup, build/sim/verify/synth flow, roadmap summary |
| `requirements.txt` | Python environment must be reproducible | Pinned dependency versions |
| `LICENSE` | Public GitHub repos should state usage terms | Project license |

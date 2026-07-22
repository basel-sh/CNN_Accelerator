# Development Roadmap — CNN Convolution Accelerator

Each phase lists its goal, primary deliverables, and the files it touches.
Work through phases in order; later phases assume earlier ones are complete.

| Phase | Name | Goal | Key files |
|---|---|---|---|
| 1 | Project Setup | Repository, folder structure, tooling, docs (this deliverable) | entire scaffold |
| 2 | Python Golden Model | Bit-accurate reference convolution (unsigned in / signed kernel / signed>=16-bit out, optional ReLU) | `Python/golden_model.py`, `convolution.py`, `image_loader.py`, `image_generator.py`, `utilities.py` |
| 3 | Memory Architecture | Define/size image, kernel, and generic RAM/FIFO primitives | `RTL/image_memory.v`, `kernel_memory.v`, `ram.v`, `fifo.v` |
| 4 | Line Buffer | Implement N-1 row buffering for sliding-window reconstruction | `RTL/line_buffer.v` |
| 5 | Window Generator | Assemble and shift the NxN window at stride 1 | `RTL/window_generator.v` |
| 6 | MAC Unit | Signed x unsigned multiply-accumulate, >=16-bit signed output | `RTL/mac.v`, `Testbench/tb_mac.v` |
| 7 | Controller FSM | Sequence kernel load, image streaming, ReLU, output handshake | `RTL/controller.v`, `Testbench/tb_controller.v` |
| 8 | Top Integration | Wire all submodules into `top.v`; define output buffering | `RTL/top.v`, `output_buffer.v` |
| 9 | Simulation | Full RTL simulation vs. golden model, automatic PASS/FAIL | `Testbench/tb_top.v`, `Python/verify.py`, `Scripts/run_simulation.tcl` |
| 10 | Optimization | Pipeline for timing, tune MAC parallelism vs. resource usage | RTL modules, `Documentation/Architecture.md` (update) |
| 11 | Synthesis | Vivado synthesis, utilization capture | `Vivado/`, `Scripts/synthesize.tcl`, `Reports/synthesis/`, `Reports/utilization/` |
| 12 | Timing Closure | Constrain and close timing at target Fmax | `Vivado/constraints.xdc`, `Reports/timing/` |
| 13 | Power Optimization | Implementation-stage power analysis and reduction | `Reports/power/` |
| 14 | Final Report | Compute Figure of Merit, assemble slides/plots | `Presentation/`, all `Reports/` |

## Notes

- Phases 2 and 3 can proceed in parallel (Python golden model has no RTL
  dependency).
- Phase 9 (Simulation) is the hard verification gate: nothing proceeds to
  Phase 11 (Synthesis) until `Python/verify.py` reports PASS across the test
  image/kernel set generated in Phases 2 and 9.
- Phases 10-13 are iterative: optimization may be revisited after seeing
  timing/utilization/power reports.

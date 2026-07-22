# Development Roadmap — CNN Convolution Accelerator

Each phase lists its goal, primary deliverables, and the files it touches.
Work through phases in order; later phases assume earlier ones are complete.

| Phase | Status | Name | Goal | Key files |
|---|---|---|---|---|
| 1 | DONE | Project Setup | Repository, folder structure, tooling, docs (this deliverable) | entire scaffold |
| 2 | DONE | Python Golden Model | Bit-accurate reference convolution (unsigned in / signed kernel / signed>=16-bit out, optional ReLU) | `Python/golden_model.py`, `convolution.py`, `image_loader.py`, `image_generator.py`, `utilities.py` |
| 3 | DONE | Memory Architecture | Define/size image, kernel, and generic RAM/FIFO primitives | `RTL/image_memory.v`, `kernel_memory.v`, `ram.v`, `fifo.v` |
| 4 | DONE | Line Buffer | Implement N-1 row buffering for sliding-window reconstruction | `RTL/line_buffer.v` |
| 5 | DONE | Window Generator | Assemble and shift the NxN window at stride 1 | `RTL/window_generator.v` |
| 6 | DONE | MAC Unit | Signed x unsigned multiply-accumulate, >=16-bit signed output | `RTL/mac.v`, `Testbench/tb_mac.v` |
| 7 | DONE | Controller FSM | Sequence kernel load, image streaming, ReLU, output handshake | `RTL/controller.v`, `Testbench/tb_controller.v` |
| 8 | DONE | Top Integration | Wire all submodules into `top.v`; define output buffering | `RTL/top.v`, `output_buffer.v` |
| 9 | DONE | Simulation | Full RTL simulation vs. golden model, automatic PASS/FAIL | `Testbench/tb_top.v`, `Python/verify.py`, `Scripts/run_simulation.tcl` |
| 10 | TODO | Optimization | Pipeline for timing, tune MAC parallelism vs. resource usage | RTL modules, `Documentation/Architecture.md` (update) |
| 11 | TODO | Synthesis | Vivado synthesis, utilization capture | `Vivado/`, `Scripts/synthesize.tcl`, `Reports/synthesis/`, `Reports/utilization/` |
| 12 | TODO | Timing Closure | Constrain and close timing at target Fmax | `Vivado/constraints.xdc`, `Reports/timing/` |
| 13 | TODO | Power Optimization | Implementation-stage power analysis and reduction | `Reports/power/` |
| 14 | TODO | Final Report | Compute Figure of Merit, assemble slides/plots | `Presentation/`, all `Reports/` |

See `Documentation/VerificationResults.md` for Phase 9 simulation evidence.

## Notes

- Phases 2 and 3 can proceed in parallel (Python golden model has no RTL
  dependency).
- Phase 9 (Simulation) is the hard verification gate: nothing proceeds to
  Phase 11 (Synthesis) until `Python/verify.py` reports PASS across the test
  image/kernel set generated in Phases 2 and 9.
- Phases 10-13 are iterative: optimization may be revisited after seeing
  timing/utilization/power reports.

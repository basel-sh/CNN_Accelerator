# Development Roadmap — CNN Convolution Accelerator

This project went through two rounds: build a correct 1-pixel/cycle baseline
first, then explore how to raise throughput without wrecking the Figure of
Merit. The baseline and one throughput experiment (a 4-DSP, second-clock-domain
design) were both eventually removed from the repo once the current design
replaced them — their history stays in `Documentation/OptimizationLog.md` and
`Documentation/Aggressive2px.md`.

| Phase | Status | Name | Goal | Key files |
|---|---|---|---|---|
| 1-9 | DONE (superseded) | Setup -> golden model -> 1px RTL -> simulation | First correct, verified design | removed baseline RTL; see `OptimizationLog.md` |
| 10 | DONE (superseded) | 1px FoM optimization | Cut LUT/FF, fix DRC/reset hazards, settle on 20 MHz | `OptimizationLog.md` |
| 11-13 | DONE (superseded) | 2px/cycle exploration | Try sharing DSPs over a fast second clock; it worked in sim but never closed timing | `Aggressive2px.md` |
| 14 | **DONE — current design** | Zero-DSP `top_2px.v` adopted | Same 20 MHz clock as everything else, 18 fabric multiplies, zero DSP, zero CDC logic. Routed: LUT 1411, FF 638, DSP 0, BRAM 1.0, 0.120 W, WNS +35.076 ns, FoM 1.10e-2 | `RTL/top_2px.v`, `RTL/mac_pair.v`, `Reports/` |
| 15 | TODO | Robustness pass | Verify the second kernel (`Images/kernels/random_3x3_test2.mem`) and ReLU-on through the Vivado flow, not just the demo edge-detect case | `Testbench/tb_top_2px.v`, `Python/verify.py` |
| 16 | TODO | Final report | Assemble `Documentation/` + `Reports/` + `Presentation/` into the competition submission | `Presentation/`, all `Documentation/` |

## Notes

- The design in `RTL/` today is final for this competition cycle: one
  architecture, one Vivado project (`Vivado_2px/`), one set of reports
  (`Reports/`).
- Phase 15 matters because every PASS/FAIL result recorded so far for the
  current design used the same one demo image/kernel pair. See root
  `README.md`'s command reference for exactly how to run the second-kernel
  and ReLU-on checks.

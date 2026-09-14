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
| 14 | DONE (superseded by 17) | Zero-DSP `top_2px.v` adopted | Same 20 MHz clock as everything else, 18 fabric multiplies, zero DSP, zero CDC logic. Routed: LUT 1411, FF 638, DSP 0, BRAM 1.0, 0.120 W, WNS +35.076 ns, FoM 1.10e-2 | `RTL/top_2px.v`, `RTL/mac_pair.v`, `Reports/` |
| 15 | **DONE** | Robustness pass | Verify a second real input photo and a second kernel (horizontal-Sobel) through the Vivado flow — both **900/900 bit-exact**. ReLU-on is exercised in the Icarus suite (`tb_generic.v`'s `RELU` parameter) but the dedicated Vivado XSim run with `RELU=1` is still open | `Testbench/tb_top_2px.v`, `Python/verify.py` |
| 16 | **DONE — verification audit** | Formal test plan + Icarus regression | 46-row `Verification_Test_Plan.xlsx`; found and fixed two real bugs (silent output drop with no consumer, hardcoded-K adder tree) via a new 10-testbench Icarus suite (`Testbench/audit_icarus_2026-09-12/`), including a brand-new AXI4-Lite slave (`axi_lite_top_2px.v`) and its own bus-functional test | `Verification_Test_Plan.xlsx`, `Testbench/audit_icarus_2026-09-12/`, `RTL/fifo_pair.v`, `RTL/axi_lite_top_2px.v` |
| 17 | **DONE — current design, final** | Kernel-scoped bit-width optimization | Narrowed `Kernel_W`/`Acc_W` to this design's verified kernel class (4-bit/16-bit), re-verified bit-exact, then resynthesized. Routed: LUT 896, FF 1049, DSP 0, BRAM 1.0, 0.113 W, WNS +33.802 ns, **FoM 1.777e-2 — best of every phase** | `RTL/top_2px.v`, `RTL/mac_pair.v`, `Python/verify.py`, `Reports/` |
| 18 | TODO | Final report polish | `Final_Report_SiliconMinds.docx`/`.pdf` and `Presentation/` are assembled and current; only remaining open item is the dedicated Vivado ReLU-on run from phase 15 | `Final_Report_SiliconMinds.docx`, `Presentation/` |

## Notes

- The design in `RTL/` today is final for this competition cycle: one
  architecture, one Vivado project (`Vivado_2px/`), one set of reports
  (`Reports/`), plus the optional `axi_lite_top_2px.v` wrapper.
- The only functional item still open across the whole roadmap is the
  dedicated Vivado XSim run with `RELU=1` — everything else recorded above,
  including the AXI4-Lite path and the bit-width optimization, has been run
  and re-verified for real. See root `README.md`'s command reference for
  exactly how to run it.

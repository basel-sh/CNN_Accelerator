# Images/kernels/

Programmable NxN signed 8-bit kernel coefficient files (`$readmemh` hex,
one coefficient per line, row-major), consumed by `RTL/kernel_memory.v`
via `Testbench/tb_top.v`.

| File | Purpose |
|---|---|
| `edge_3x3.mem` | Vertical Sobel edge-detection kernel — written by `Python/prepare_stimulus.py` |
| `random_3x3_test2.mem` | Extra random signed kernel used for ad-hoc regression testing |

To use a different kernel, edit/replace the array in `Python/prepare_stimulus.py`
(or write a new `.mem` file in this format) and re-run the Quick Start flow.

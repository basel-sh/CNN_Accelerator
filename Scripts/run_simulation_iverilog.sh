#!/usr/bin/env bash
#==============================================================================
# run_simulation_iverilog.sh
# Optional FAST local verification loop using Icarus Verilog (open-source),
# for quick iteration without opening Vivado. Vivado's own simulator
# (Scripts/run_simulation.tcl) is still the flow used for the official
# competition-required simulation; this script is a convenience alternative
# that exercises the exact same RTL/Testbench/Python golden-model pipeline.
#
# Requires: iverilog + vvp on PATH (apt install iverilog / brew install
# icarus-verilog), and the Python venv from requirements.txt.
#
# Usage: bash Scripts/run_simulation_iverilog.sh
#==============================================================================
set -e
cd "$(dirname "$0")/.."   # repo root
mkdir -p sim

echo "== [1/4] Generating stimulus (Python golden model) =="
python3 - <<'PYEOF'
import sys; sys.path.insert(0, "Python")
from image_generator import generate_test_image, generate_test_kernel
from golden_model import run_golden_model
from image_loader import write_mem_file

Pixel_W, Kernel_W, Acc_W = 8, 8, 20
Img = generate_test_image(32, 32, "random", Seed=42, Pixel_Width=Pixel_W)
Ker = generate_test_kernel(3, "edge", Kernel_Width=Kernel_W)
Out = run_golden_model(Img, Ker, Apply_Relu=False, Pixel_Width=Pixel_W, Kernel_Width=Kernel_W, Acc_Width=Acc_W)
write_mem_file(Img, "Images/input_32x32.mem", Pixel_W, Signed=False)
write_mem_file(Ker, "Images/kernels/edge_3x3.mem", Kernel_W, Signed=True)
write_mem_file(Out, "Images/expected_output.mem", Acc_W, Signed=True)
PYEOF

echo "== [2/4] Compiling RTL + testbench with Icarus Verilog =="
iverilog -g2005 -o sim/tb_top.out \
  RTL/ram.v RTL/fifo.v RTL/image_memory.v RTL/kernel_memory.v RTL/line_buffer.v \
  RTL/window_generator.v RTL/mac.v RTL/controller.v RTL/output_buffer.v RTL/top.v \
  Testbench/tb_top.v

echo "== [3/4] Running simulation =="
vvp sim/tb_top.out

echo "== [4/4] Comparing RTL output to the golden model =="
python3 Python/verify.py --image Images/input_32x32.mem \
  --kernel Images/kernels/edge_3x3.mem --rtl-output sim/rtl_output.mem \
  --img-size 32 32 --k 3 --acc-width 20

echo "== Waveform =="
echo "Dumped to sim/tb_top.vcd -- open it with: gtkwave sim/tb_top.vcd"

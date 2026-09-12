# Verification audit testbenches (2026-09-12, updated with fixes 2026-09-12)

These are the Icarus Verilog testbenches used to actually run every row of
`Verification_Test_Plan.xlsx` and fill in real Status + Audit Notes. They are
independent of the Vivado/XSim flow in `Scripts/` and `Testbench/tb_top_2px.v`
(which is untouched) - a second, cheap way to re-check the design without
needing a Vivado license/session.

## Setup (one time)

```
sudo apt-get install iverilog        # Linux
# or: choco install icarus-verilog   # Windows, if you want to run these locally
```

## Files

- `tb_generic.v` - reusable single-frame top_2px.v harness (geometry via -P
  overrides), used for most FUNC-01/03/05/06/07 and all BND-xx rows.
- `tb_mac_unit.v` - drives `RTL/mac_pair.v` directly (FUNC-08, TIM-07,
  BND-07, BND-08).
- `tb_ctrl_unit.v` - drives `RTL/controller_2px.v` directly (FUNC-09,
  RST-01, RST-02, TIM-01, TIM-03, TIM-04, TIM-05, B2B-01, B2B-02).
- `tb_kernel_unit.v` - drives `RTL/kernel_memory.v` directly (BND-11,
  RST-05, ERR-02).
- `tb_imgmem_unit.v` - drives `RTL/image_memory_2px.v` directly (ERR-01).
- `tb_reload_switch.v`, `tb_rst04.v`, `tb_b2b04.v`, `tb_tim02.v`,
  `tb_backpressure.v` - multi-phase top_2px.v scenarios (FUNC-04, B2B-03,
  RST-04, B2B-04, TIM-02, ERR-03, ERR-04, TIM-06, RST-03, ERR-05).
  `tb_backpressure.v` was rewritten 2026-09-12 to assert the new (fixed)
  FIFO-backed behavior for ERR-04/TIM-06 instead of the old no-FIFO behavior.
- `tb_axi_lite.v` - **new 2026-09-12**, drives real AXI4-Lite write/read
  handshakes against `RTL/axi_lite_top_2px.v` (TIM-08, TIM-09, ERR-06, ERR-07).

## Example run (unit-level)

```
iverilog -g2012 -o mac_unit.vvp tb_mac_unit.v RTL/mac_pair.v
vvp mac_unit.vvp
```

## Example run (generic top-level harness)

```
iverilog -g2012 -o run.vvp \
  -Ptb_generic.Img_W=64 -Ptb_generic.Img_H=64 -Ptb_generic.K=3 \
  -Ptb_generic.Img_Addrw=12 -Ptb_generic.Kidxw=4 \
  tb_generic.v RTL/top_2px.v RTL/controller_2px.v RTL/image_memory_2px.v \
  RTL/kernel_memory.v RTL/line_buffer_2px.v RTL/window_generator_2px.v RTL/mac_pair.v
vvp run.vvp
python Python/verify.py --image mem/image.mem --kernel mem/kernel.mem \
  --rtl-output sim/rtl_output.mem --img-size 64 64 --k 3
```
(`mem/image.mem` / `mem/kernel.mem` need to be generated first - see
`generic_tests.py`/`runner.py` for how stimulus was produced for each row.)

## Fixes applied 2026-09-12 (all 4 Failed + 4 Blocked rows now Passed)

**FUNC-07 (was Failed, real bug, now fixed):** `RTL/mac_pair.v`'s final
adder tree (`L0..L8`, `R0..R8`, `L_Sum`, `R_Sum`) was hardcoded to sum
exactly 9 product terms, silently dropping every tap beyond index 8 for
K != 3 (confirmed: K=5 produced 784/784 wrong outputs). Replaced with a
generic `for`-loop reduction over all `N=K*K` terms. Re-ran the same K=5
case: 784/784 now bit-exact, 0 mismatches. K=3 regression (`tb_mac_unit.v`,
full `generic_tests.py` suite) re-confirmed clean.

**ERR-04 / TIM-06 (were Failed, real bug, now fixed):** `top_2px.v`
hard-wired `Out_Full = 1'b0` with no FIFO/queue anywhere, so a result
computed while `Out_Rd_En=0` was silently overwritten the next cycle
instead of held. Added a new 16-deep FWFT queue, `RTL/fifo_pair.v`
(`Wptr`/`Rptr` with an extra MSB bit for full/empty, matching the language
the plan itself used), instantiated between `mac_pair.v` and the output
ports in `top_2px.v`. Re-ran `tb_backpressure.v` (rewritten for the new
behavior): `Out_Full` now genuinely asserts once the 16-deep queue fills,
and `Out_Data0` now holds its value across multiple cycles while unread.
Full top-level regression suite re-run against the FIFO-integrated
`top_2px.v` with no new failures (the FIFO adds one cycle of pipeline
latency, but does not affect final bit-exactness or output counts).

**TIM-03 (was Failed\*, plan-wording issue, not an RTL bug):** the gating
logic (`Row>=K-1 && Col>=K-1`) was already correct. The row only failed
because the plan's expected pulse-count formula
`(Img_W-K+1)*(Img_H-K+1)` assumes the old 1-output/cycle design; the `_2px`
architecture emits one `Pair_Valid` pulse per cycle for a *pair* of
outputs, so the correct count is that formula `/2`. No RTL changed;
recommend updating the plan's Expected Result text.

**TIM-08, TIM-09, ERR-06, ERR-07 (were Blocked, no RTL existed, now
unblocked and passing):** wrote a new module, `RTL/axi_lite_top_2px.v` - a
standard AXI4-Lite slave (`aw_en`-arbitrated write channel, matching the
term the plan itself names) wrapping `top_2px.v`, with a register map
documented in the file's header comment (0x00 CONTROL/STATUS, 0x08/0x0C
IMG_WADDR+WDATA, 0x10/0x14 KERNEL_WINDEX+WDATA, 0x18 OUT_DATA). Wrote
`tb_axi_lite.v` to drive real AXI write/read handshakes against it: a
0x14 write pulses `Kernel_We` for exactly 1 cycle (TIM-08); a 0x18 read
returns `Out_Data0` sign-extended and matches the DUT's raw output
bit-exact (TIM-09); an undecoded 0x1C access returns OKAY with no side
effect (ERR-06); a 0x18 read while empty still pulses `Out_Rd_En`
unconditionally and completes with OKAY, no hang (ERR-07).

**Caveat that still applies:** this whole fix-and-reverify pass, like the
original audit, used Icarus Verilog in a cloud sandbox, not the official
Vivado/XSim flow. Re-run the real Vivado simulation against this RTL before
final submission - especially important now since actual RTL changed, not
just test-status bookkeeping. The AXI-Lite register map in
`axi_lite_top_2px.v` is a new design (no spec for it existed anywhere in
the repo before this fix) - if the competition or a downstream integration
expects a *specific* register map, this one should be checked against it.

# Aggressive 2-pixel/cycle FoM experiment

This branch preserves the verified 1-pixel/cycle implementation in `RTL/top.v` and explores higher-FoM 2-pixel/cycle architectures. `master` is intentionally untouched.

## 1. Architecture and correctness baseline

For the default 32x32 grayscale image with K=3:

- 512 two-pixel input blocks are streamed.
- 900 valid output pixels are produced.
- The target steady-state throughput is **2 output pixels/system-cycle**.
- A programmable 3x3 kernel requires 9 products per output.
- Two adjacent outputs therefore require **18 exact products** per pair. The overlapping pixels cannot simply reuse their old products because the one-pixel shift changes the kernel coefficient associated with each shared pixel.

The 2px front end consists of the 2px controller, dual-port image memory, 2px line buffer and 2px window generator.

## 2. MP4 candidate: first FoM optimization

The first aggressive arithmetic candidate used four shared DSP multipliers at 120 MHz while the system interface remained at 20 MHz:

- system clock: 20 MHz, 50 ns period
- fast MAC clock: 120 MHz, 8.333 ns period
- DSPs: 4
- exact products/pair: 18
- fast slots/pair: 5
- target throughput: 2 output pixels/cycle

The 20 MHz -> 120 MHz request path was upgraded from a toggle mailbox to a **16-entry FWFT asynchronous FIFO** in distributed RAM. The result path also uses CDC buffering so a completed pair cannot be overwritten before the 20 MHz side consumes it.

### Functional verification reached

The MP4 RTL was simulated on the 32x32 / 3x3 edge-detection case and produced:

```text
TB_TOP_2PX_MP4: captured 900 outputs from 450 pairs (expected 900 outputs)
TB_TOP_2PX_MP4: OUTPUT COUNT MATCHES EXPECTATION
```

Golden-model comparison:

```text
Compared 900 output values.
RESULT: PASS - RTL output matches the golden model exactly.
```

This establishes **functional correctness for the tested configuration** before the next physical-implementation optimization.

## 3. Measured MP4 implementation results

The following values are from the **routed implementation reports**, not estimates:

| Metric | Original baseline | MP4 routed | Change |
|---|---:|---:|---:|
| Throughput | 1 px/cycle | 2 px/cycle target | +100% |
| LUT | 842 | 738 | -12.35% |
| FF | 758 | 1286 | +69.66% |
| DSP | 0 | 4 | +4 |
| BRAM | 0.5 | 1.0 | +0.5 |
| Total power | 0.149 W | 0.233 W | +56.38% |
| Fast-clock WNS | +35.538 ns baseline clock | **-4.338 ns @ 120 MHz** | timing failure |

The MP4 routed timing report shows:

```text
Clk_Fast_Raw WNS = -4.338 ns
Clk_Fast_Raw TNS = -242.680 ns
Failing endpoints = 118
```

The critical path is in the accumulator datapath, approximately:

```text
DSP48E1 -> fabric CARRY4/LUT accumulation -> Acc_B register
```

The routed report identifies a data-path delay of about 12.589 ns against the 8.333 ns requirement. Therefore, the 120 MHz clock is **not timing closed**.

### Provisional MP4 FoM

Using the competition formula:

```text
FoM = Throughput / (Power * (LUT + 50*DSP + 100*BRAM))
```

Baseline:

```text
FoM_old = 1 / (0.149 * (842 + 50*0 + 100*0.5))
        = 7.524e-3
```

MP4 mathematical result:

```text
FoM_MP4_provisional = 2 / (0.233 * (738 + 50*4 + 100*1))
                    = 8.269e-3
```

Mathematical improvement:

```text
8.269e-3 / 7.524e-3 - 1 = +9.91%
```

**Important reporting rule:** this 8.269e-3 value is a **provisional mathematical FoM only**. It must not be presented as the final competition FoM because the 120 MHz fast clock has negative WNS.

## 4. What is good and what is bad in MP4

### Positive results

- Throughput target doubled from 1 to 2 px/cycle.
- LUT usage fell by 104 LUTs, or 12.35%.
- The design is functionally verified against the golden model.
- The request FIFO is distributed RAM, avoiding another BRAM penalty.
- The 4-DSP architecture is dramatically smaller than the fully parallel 18-multiplier design.

### Negative results

- FF usage increased from 758 to 1286 (**69.66% worse**). This is a real weakness and must be reduced.
- DSP count increased from 0 to 4, which directly costs `4*50=200` in the FoM denominator.
- BRAM increased from 0.5 to 1.0, adding another 50 denominator points.
- Power increased from 0.149 W to 0.233 W.
- Most importantly, the 120 MHz fast-clock timing constraint failed by 4.338 ns.

## 5. Next optimization: MP3 DSP48E1 accumulator architecture

The next implementation replaces the four-DSP fabric-accumulator engine with **three DSP48E1 slices using the DSP's internal P-register accumulator**.

The schedule is:

```text
slot 0 -> L0 L1 L2
slot 1 -> L3 L4 L5
slot 2 -> L6 L7 L8
slot 3 -> R0 R1 R2
slot 4 -> R3 R4 R5
slot 5 -> R6 R7 R8
```

Thus:

```text
3 DSPs * 6 fast cycles = 18 exact products/pair
6 * 8.333 ns = 50 ns
```

The key change is not merely reducing DSP count. The previous critical path contained a **fabric carry-chain accumulation after the DSP multiplier**. The MP3 architecture moves the accumulation into the DSP48E1 P-register datapath. This is specifically intended to remove the long fabric `DSP -> CARRY4 -> register` path that caused the -4.338 ns violation.

The three partial sums for each output are transported through a small distributed asynchronous FIFO. The final three-way additions are performed at the 20 MHz system clock, where timing margin is abundant compared with the 120 MHz domain.

### FF-reduction strategy

The MP4 result FIFO was implemented as explicit register arrays plus Gray-pointer CDC logic. The MP3 implementation moves the result buffering into an **XPM asynchronous distributed-memory FIFO**. This removes the explicit result-data register array and most of its associated CDC pointer registers from the user RTL.

The MP3 arithmetic engine also removes the MP4 `Acc_A/Acc_B` fabric accumulators and their wide combinational adder network.

The expected direction is therefore:

```text
FF: 1286  -> substantially lower target
DSP: 4    -> 3
critical fast-clock path: fabric accumulation -> DSP internal accumulation
```

The exact post-route values must be taken from Vivado; they are not assumed here.

## 6. Timing-closure objective

The hard requirement for the 2px architecture is:

```text
system clock = 20 MHz
fast clock   = 120 MHz
fast period  = 8.333 ns
WNS           >= 0 ns
```

A fast clock below approximately 100 MHz would not provide six 8.333-ns-equivalent microcycles inside the 50-ns system cycle. Therefore, simply slowing the clock is not an acceptable fix for the 2px/cycle target. The datapath itself must be optimized.

The first timing-closure target is therefore:

1. remove the fabric accumulator from the critical path;
2. preserve 120 MHz;
3. preserve exact 18-product arithmetic;
4. preserve 2 output pixels/system-cycle;
5. re-run routed timing and verify WNS >= 0 ns.

## 7. Verification procedure after MP3 changes

Run behavioral simulation first:

```tcl
cd C:/Users/Xps/Desktop/CNN_Accelerator
source Scripts/run_simulation_2px_mp4.tcl
```

Then compare against the golden model:

```powershell
python Python/verify.py --image Images/input_32x32.mem --kernel Images/kernels/edge_3x3.mem --rtl-output sim/rtl_output_2px_mp4.mem --img-size 32 32 --k 3 --acc-width 20
```

Expected functional result:

```text
Compared 900 output values.
RESULT: PASS - RTL output matches the golden model exactly.
```

After behavioral PASS, run:

```tcl
source Scripts/synthesize_2px_mp4.tcl
```

Record from the **routed** reports:

- LUT
- FF
- DSP
- BRAM
- total power
- dynamic power
- static power
- WNS/TNS
- Fmax

Only after timing closure should the new FoM be treated as a final competition result.

## 8. Competition FoM threshold

The preserved baseline is:

```text
T    = 1 px/cycle
LUT  = 842
FF   = 758
DSP  = 0
BRAM = 0.5
P    = 0.149 W
FoM  = 7.524e-3
```

For `T=2`, beating the baseline requires:

```text
P * (LUT + 50*DSP + 100*BRAM) < 265.816
```

With three DSPs and one BRAM, the condition becomes:

```text
P * (LUT + 250) < 265.816
```

This is the new optimization target for the MP3 implementation.

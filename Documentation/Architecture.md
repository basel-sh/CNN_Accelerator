# Architecture — CNN Convolution Accelerator

Status: **implemented, verified, synthesized, timing-closed.** This document
describes the RTL exactly as built in `RTL/`; signal names follow the
`First_Second` naming convention (see root `README.md`). This is the only
design in the repository — an earlier 1-pixel/cycle baseline and a 4-DSP,
second-clock-domain variant were both explored and abandoned along the way;
that history is kept in `Documentation/OptimizationLog.md` and
`Documentation/Aggressive2px.md` for the record, but neither one is part of
the current tree.

## 1. High-Level Architecture

```
                  ┌────────────────────── controller_2px.v (FSM) ──────────────────────┐
                  │                                                                     │
   host / tb ───▶│  kernel load          image stream control          ReLU enable      │
                  └──────┬────────────────────────┬──────────────────────┬─────────────┘
                         ▼                         ▼                      ▼
                 kernel_memory.v          image_memory_2px.v         (ctrl signals)
                         │                (dual read port, 2 px/cycle)
                         │                         │
                         │                ┌────────▼─────────┐
                         │                │ line_buffer_2px.v │  (K-1 row buffers, 2 lanes)
                         │                └────────┬──────────┘
                         │                         ▼
                         │            ┌───────────────────────────┐
                         └───────────▶│  window_generator_2px.v   │  (2 overlapping KxK windows)
                                      └─────────────┬──────────────┘
                                                     ▼
                                            ┌─────────────────┐
                                            │   mac_pair.v     │  (18 fabric multiplies,
                                            │                  │   balanced adder tree x2,
                                            │                  │   zero DSP, single clock)
                                            └────────┬──────────┘
                                                      ▼
                                            top_2px.v: Out_Data0, Out_Data1
                                          (ReLU applied inline, one mux per lane)
```

`top_2px.v` is the wrapper instantiating and wiring all of the above. Everything
runs off a single clock (`Clk`, 20 MHz in the tracked constraints) — there is no
second clock domain, no clock-domain-crossing logic, and no DSP48 instance
anywhere in this design.

## 2. Dataflow

1. Kernel coefficients (signed 8-bit, KxK) are loaded into `kernel_memory.v`
   once per convolution configuration — shared, unmodified from the original
   design.
2. The input image (unsigned fixed-point, >=32x32) is streamed two pixels per
   cycle from `image_memory_2px.v`, which exposes two independent read ports
   onto one dual-port Block RAM.
3. `line_buffer_2px.v` retains the previous K-1 rows for both pixel lanes, so
   two full KxK neighborhoods are available every cycle.
4. `window_generator_2px.v` assembles two adjacent, overlapping KxK windows
   (window A and window B, one pixel apart) each cycle, stride = 1.
5. `mac_pair.v` computes both outputs exactly: because a one-pixel shift pairs
   each shared input pixel with a *different* kernel coefficient, the overlap
   between window A and window B cannot be exploited arithmetically — all 18
   products (9 per window) are computed independently, in fabric, with zero
   DSPs, through a 2-stage pipeline (register the 18 products, then a balanced
   binary adder tree per lane, then register the two sums).
6. `top_2px.v` applies ReLU inline (a single mux per output lane, no separate
   `output_buffer.v`/FIFO stage) and drives `Out_Data0`/`Out_Data1` combined
   with `Out_Valid`.

## 3. Datapath Widths (minimum, per competition spec)

| Signal | Width | Sign |
|---|---|---|
| Input pixel | 8-bit fixed-point | unsigned |
| Kernel coefficient | 8-bit | signed |
| MAC accumulator / output | 20-bit (exceeds the 16-bit minimum; see `Documentation/PerformanceResults.md` for the overflow-proof-by-construction justification) | signed |

## 4. Memory Hierarchy

- `image_memory_2px.v` — holds the full input frame in one Block RAM tile,
  exposed through two independent read ports (2 RAMB18E1, 1.0 in 36k-equivalent
  units).
- `kernel_memory.v` — small, holds only the KxK coefficients; reprogrammable;
  unchanged from the original single-pixel-per-cycle design.
- `line_buffer_2px.v` — K-1 row-deep buffering, duplicated across both pixel
  lanes, avoiding re-reading `image_memory_2px.v` for every window position.

There is no generic `ram.v`/`fifo.v` primitive layer in this design — the
image memory infers Block RAM directly (`(* ram_style = "block" *)`), and
there's no elastic output FIFO, since `top_2px.v` drives its two result lanes
straight out with a registered valid flag.

## 5. FSM Overview (`controller_2px.v`)

Same shape as the original controller — `S_Idle -> S_Run -> S_Done -> S_Idle`,
`S_Run` drives the raster-scan read addresses (`Mem_Raddr0`/`Mem_Raddr1`, two
pixels apart) and raises `Pair_Valid` once a full pair of KxK windows exists.
`top_2px.v` re-times that raw valid tag by two extra cycles
(`Pair_Valid_D1`/`Pair_Valid_D2`) to match `image_memory_2px.v`'s read latency
and `window_generator_2px.v`'s register before it reaches `mac_pair.v`.

## 6. Line Buffer / Window Generator Concept

Both are the same concept as a 1-pixel/cycle design, just run twice — once per
pixel lane — with the two lanes offset by exactly one column so that window B
is always window A shifted right by one pixel. `window_generator_2px.v` keeps
two sets of K small horizontal shift registers (one set per lane), each of
depth K; together they form the two active convolution windows, sliding right
by two columns every cycle (one column per output produced per cycle).

## 7. MAC Array (`mac_pair.v`)

18 pixel*coefficient products (9 per window) are computed fully in parallel,
in FPGA fabric, using no DSP48 primitives. Each product is registered, then
reduced through a balanced binary adder tree (4 levels for K=3, `ceil(log2(9))`)
into a 20-bit signed sum per lane, registered again at the output. Total
pipeline latency from `Valid_In` to `Valid_Out` is 2 cycles. This is the
direct, deliberate alternative to sharing a handful of DSP48 slices over a
second, faster clock — that approach was tried (`Documentation/Aggressive2px.md`),
worked in simulation, but never closed timing (WNS -4.338 ns) because of the
DSP-output accumulation path plus the clock-domain-crossing FIFOs it needed.
Running everything at one clock and paying for 18 fabric multipliers instead
is what actually closes timing, at +35.076 ns of slack.

## 8. Input / Output Buffering

- Input side: `image_memory_2px.v` decouples the source image from the
  streaming pipeline's timing, same role as before, now with two read ports.
- Output side: no separate buffer/FIFO stage — `top_2px.v` drives
  `Out_Data0`/`Out_Data1` directly off `mac_pair.v`'s registered outputs, gated
  by `Out_Valid` and `Out_Rd_En`. ReLU is a single combinational mux per lane
  at the top-level output, not a dedicated module.

## 9. Pipeline Overview

Fully streaming steady state: two new pixels in, and — after an initial
KxK-window-pair fill latency — two new results out, every cycle, at 20 MHz.
Routed implementation: LUT 1411, FF 638, DSP 0, BRAM 1.0, 0.120 W, WNS
+35.076 ns (all constraints met). Full numbers and the FoM calculation:
`Reports/` and `Documentation/PerformanceResults.md`.

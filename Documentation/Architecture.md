# Architecture — CNN Convolution Accelerator

Status: design description only. No RTL logic exists yet — this document is
the reference implementers (you, later) will code against.

## 1. High-Level Architecture

```
                 ┌─────────────────────────── controller.v (FSM) ───────────────────────────┐
                 │                                                                            │
   host / tb ───▶│  kernel load          image stream control          ReLU enable            │
                 └──────┬───────────────────────────┬──────────────────────┬──────────────────┘
                        ▼                            ▼                      ▼
                kernel_memory.v              image_memory.v            (ctrl signals)
                        │                            │
                        │                    ┌───────▼────────┐
                        │                    │  line_buffer.v  │  (N-1 row buffers, fifo.v/ram.v)
                        │                    └───────┬────────┘
                        │                            ▼
                        │                 ┌──────────────────────┐
                        └────────────────▶│  window_generator.v  │  (assembles NxN sliding window)
                                           └──────────┬───────────┘
                                                      ▼
                                              ┌───────────────┐
                                              │    mac.v      │  (multiply-accumulate array)
                                              └───────┬───────┘
                                                      ▼
                                            ┌───────────────────┐
                                            │  output_buffer.v  │  (optional ReLU, streaming out)
                                            └───────┬───────────┘
                                                     ▼
                                                 top.v output
```

`top.v` is the wrapper instantiating and wiring all of the above.

## 2. Dataflow

1. Kernel coefficients (signed 8-bit, NxN) are loaded into `kernel_memory.v`
   once per convolution configuration.
2. The input image (unsigned fixed-point, >=32x32) is streamed row-by-row
   from `image_memory.v` under `controller.v` sequencing.
3. `line_buffer.v` retains the previous N-1 rows so that, combined with the
   current incoming pixel, a full NxN neighborhood is always available.
4. `window_generator.v` assembles that neighborhood into the sliding NxN
   window, shifting by one pixel per cycle (stride = 1).
5. `mac.v` multiplies each window sample by its corresponding kernel
   coefficient and accumulates into a signed >=16-bit partial sum.
6. `output_buffer.v` optionally applies ReLU (clamp negative values to zero)
   and streams the final signed >=16-bit result out of `top.v`.

## 3. Datapath Widths (minimum, per competition spec)

| Signal | Width | Sign |
|---|---|---|
| Input pixel | fixed-point, unsigned | unsigned |
| Kernel coefficient | 8-bit | signed |
| MAC accumulator / output | >=16-bit | signed |

## 4. Memory Hierarchy

- `image_memory.v` — holds the full input frame; feeds the streaming pipeline.
- `kernel_memory.v` — small, holds only the NxN coefficients; reprogrammable.
- `line_buffer.v` — N-1 row-deep buffering (built from `fifo.v` / `ram.v`)
  to avoid re-reading `image_memory.v` for every window position.
- `ram.v` / `fifo.v` — generic primitives underlying all of the above, chosen
  so they map cleanly onto Xilinx Block RAM / distributed RAM at synthesis.

## 5. FSM Overview (`controller.v`)

Conceptual states (finalized during Phase 7):

`IDLE → LOAD_KERNEL → STREAM_ROWS → WINDOW_VALID → (RELU) → OUTPUT_VALID → DONE / STREAM_ROWS (loop)`

The FSM gates when the line buffer shifts, when the window generator's output
is valid, when the MAC array should accumulate vs. flush, and when ReLU is
applied before handing data to the output buffer.

## 6. Line Buffer Concept

For an NxN kernel, N-1 line buffers (each one image-row deep) run in
lock-step with the incoming pixel stream. Every cycle, the oldest row shifts
into the next buffer and the newest pixel shifts in, so the vertical NxN
neighborhood for the current column is always present across the current
pixel + the N-1 buffered rows.

## 7. Window Generation Concept

`window_generator.v` takes one pixel per cycle from each of the N row
sources (current pixel + line buffer taps) and maintains N small horizontal
shift registers, one per row, of depth N. Together these N×N registers form
the current convolution window; every cycle the window slides right by one
column (stride = 1).

## 8. MAC Array Concept

At minimum, one MAC unit sequentially processes the N×N window per output
pixel (N² multiply-accumulate cycles); a scalable variant instantiates
multiple `mac.v` units in parallel (e.g., one per kernel row, or a fully
unrolled N×N array) to trade DSP/LUT usage for throughput. This tradeoff is
evaluated explicitly in Phase 10 (Optimization) against the resource and
throughput scoring criteria.

## 9. Input / Output Buffering

- Input side: `image_memory.v` decouples the source image from the streaming
  pipeline's timing.
- Output side: `output_buffer.v` (built on `fifo.v`) decouples MAC production
  timing from whatever consumes the result stream, and is where ReLU is
  applied if enabled.

## 10. Pipeline Overview

The steady-state pipeline is intended to be fully streaming (one new pixel
in, and — after an initial NxN-window fill latency — one new result out, per
cycle), with pipeline register stages to be inserted at MAC and buffer
boundaries during Phase 10 (Optimization) to close timing at the target
frequency. Exact stage count/placement is an implementation decision made
once real synthesis timing reports (`Reports/timing/`) are available.

//==============================================================================
// File          : mac.v
// Module        : mac
// Project       : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
// Phase         : 6 - MAC Unit (see Documentation/DevelopmentRoadmap.md)
//------------------------------------------------------------------------------
// Responsibility:
//   Single (or arrayed) Multiply-Accumulate unit that multiplies unsigned pixel samples by signed 8-bit kernel coefficients and accumulates partial sums into a signed >=16-bit result for one NxN convolution window.
//
// Interacts with : window_generator.v, kernel_memory.v, controller.v, output_buffer.v
//
// Status         : STUB ONLY - no logic implemented yet.
//                   Ports, parameters and internal logic are intentionally
//                   left as TODO until the RTL implementation phase begins.
//==============================================================================

module mac (
    // TODO: define parameter list (e.g. DATA_WIDTH, KERNEL_SIZE, ...)
    // TODO: define port list (clk, rst_n, data in/out, valid/ready handshake...)
);

    // TODO: implementation pending - do not implement before Phase 6 - MAC Unit

endmodule

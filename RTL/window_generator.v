//==============================================================================
// File          : window_generator.v
// Module        : window_generator
// Project       : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
// Phase         : 5 - Window Generator (see Documentation/DevelopmentRoadmap.md)
//------------------------------------------------------------------------------
// Responsibility:
//   Consumes the current pixel plus the line-buffer outputs to assemble the full NxN sliding convolution window each cycle, and shifts the window as the stride-1 scan advances across the image.
//
// Interacts with : line_buffer.v, mac.v, controller.v
//
// Status         : STUB ONLY - no logic implemented yet.
//                   Ports, parameters and internal logic are intentionally
//                   left as TODO until the RTL implementation phase begins.
//==============================================================================

module window_generator (
    // TODO: define parameter list (e.g. DATA_WIDTH, KERNEL_SIZE, ...)
    // TODO: define port list (clk, rst_n, data in/out, valid/ready handshake...)
);

    // TODO: implementation pending - do not implement before Phase 5 - Window Generator

endmodule

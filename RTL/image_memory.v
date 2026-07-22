//==============================================================================
// File          : image_memory.v
// Module        : image_memory
// Project       : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
// Phase         : 3 - Memory Architecture (see Documentation/DevelopmentRoadmap.md)
//------------------------------------------------------------------------------
// Responsibility:
//   Storage for the input grayscale image / feature map (>=32x32, unsigned fixed-point). Supplies pixel data to the line buffer / window generator in raster-scan order under control of the FSM.
//
// Interacts with : top.v, controller.v, line_buffer.v, ram.v
//
// Status         : STUB ONLY - no logic implemented yet.
//                   Ports, parameters and internal logic are intentionally
//                   left as TODO until the RTL implementation phase begins.
//==============================================================================

module image_memory (
    // TODO: define parameter list (e.g. DATA_WIDTH, KERNEL_SIZE, ...)
    // TODO: define port list (clk, rst_n, data in/out, valid/ready handshake...)
);

    // TODO: implementation pending - do not implement before Phase 3 - Memory Architecture

endmodule

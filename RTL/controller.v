//==============================================================================
// File          : controller.v
// Module        : controller
// Project       : CNN Convolution Accelerator - IEEE SSCS Egypt Chapter 2026
// Phase         : 7 - Controller FSM (see Documentation/DevelopmentRoadmap.md)
//------------------------------------------------------------------------------
// Responsibility:
//   Central finite-state machine that sequences the accelerator: loading kernel coefficients, streaming the input image row by row, enabling the line buffer / window generator / MAC array at the right cycles, applying optional ReLU, and signalling output-valid. Owns the overall handshake/control protocol.
//
// Interacts with : top.v, image_memory.v, kernel_memory.v, line_buffer.v, window_generator.v, mac.v, output_buffer.v
//
// Status         : STUB ONLY - no logic implemented yet.
//                   Ports, parameters and internal logic are intentionally
//                   left as TODO until the RTL implementation phase begins.
//==============================================================================

module controller (
    // TODO: define parameter list (e.g. DATA_WIDTH, KERNEL_SIZE, ...)
    // TODO: define port list (clk, rst_n, data in/out, valid/ready handshake...)
);

    // TODO: implementation pending - do not implement before Phase 7 - Controller FSM

endmodule

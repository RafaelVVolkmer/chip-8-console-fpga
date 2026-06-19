// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_display_controller.sv
// -----------------------------------------------------------------------------
// @brief Video Display controller.
// =============================================================================
//
// Responsibilities:
// - Drive scanout, capture or framebuffer transformation behavior.
// - Keep pixel timing and control paths separate.
// - Expose observable status for software and formal proofs.
//
// Characteristics:
// - Framebuffer-aware or scanout-oriented logic.
// - Uses explicit pixel geometry and timing contracts.
// - Shared across display backends and validation.
//
// Design notes:
// - Keep pixel geometry and register offsets named.
// =============================================================================
`default_nettype none

module chip8_display_controller (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        clear_i,
  input  logic        draw_we_i,
  input  logic [5:0]  draw_x_i,
  input  logic [4:0]  draw_y_i,
  input  logic [10:0] scan_addr_i,
  output logic        scan_pixel_o,
  output logic        old_pixel_o,
  output logic        new_pixel_o,
  output logic [2047:0] framebuffer_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------
  //
  // None. The framebuffer module owns the registered pixel state.

  // ------------------------------------------------------------
  // Submodule instances
  // ------------------------------------------------------------

  chip8_framebuffer u_framebuffer (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .clear_i(clear_i),
    .draw_we_i(draw_we_i),
    .draw_x_i(draw_x_i),
    .draw_y_i(draw_y_i),
    .scan_addr_i(scan_addr_i),
    .scan_pixel_o(scan_pixel_o),
    .old_pixel_o(old_pixel_o),
    .new_pixel_o(new_pixel_o),
    .framebuffer_o(framebuffer_o)
  );
endmodule

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_sprite_blitter.sv
// -----------------------------------------------------------------------------
// @brief Video Sprite blitter.
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

module chip8_sprite_blitter (
  input  logic [7:0] sprite_byte_i,
  input  logic [2:0] bit_i,
  input  logic [5:0] base_x_i,
  input  logic [4:0] base_y_i,
  input  logic [3:0] row_i,
  output logic       pixel_on_o,
  output logic [5:0] draw_x_o,
  output logic [4:0] draw_y_o
);
  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign pixel_on_o = sprite_byte_i[7 - bit_i];
  assign draw_x_o = (base_x_i + {3'b000, bit_i}) & 6'h3f;
  assign draw_y_o = (base_y_i + {1'b0, row_i}) & 5'h1f;
endmodule

`default_nettype wire

// EOF

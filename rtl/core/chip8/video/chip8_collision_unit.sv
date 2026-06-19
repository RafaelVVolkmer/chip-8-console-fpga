// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_collision_unit.sv
// -----------------------------------------------------------------------------
// @brief Video Collision unit.
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

module chip8_collision_unit (
  input  logic draw_we_i,
  input  logic old_pixel_i,
  output logic collision_o
);
  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign collision_o = draw_we_i & old_pixel_i;
endmodule

`default_nettype wire

// EOF

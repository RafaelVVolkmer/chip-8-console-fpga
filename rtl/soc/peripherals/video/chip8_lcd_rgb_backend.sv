// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_lcd_rgb_backend.sv
// -----------------------------------------------------------------------------
// @brief LCD RGB scanout backend.
// =============================================================================
//
// Responsibilities:
// - Drive an LCD-style RGB interface from the framebuffer.
// - Keep pixel timing separate from panel signaling.
// - Expose panel sync and data in a simple wrapper.
//
// Characteristics:
// - Scanout adapter for RGB LCD panels.
// - Uses the shared video timing and scaler blocks.
// - No architectural state beyond scan generation.
//
// Design notes:
// - Keep sync polarities and pixel sampling explicit.
// =============================================================================
`default_nettype none

module chip8_lcd_rgb_backend #(
  parameter int H_ACTIVE = 800,
  parameter int V_ACTIVE = 480,
  parameter int SCALE = 10,
  parameter int X_OFFSET = 80,
  parameter int Y_OFFSET = 80
) (
  input  logic          clk_i,
  input  logic          rst_ni,
  input  logic          enable_i,
  input  logic [7:0]    scale_cfg_i,
  input  logic          invert_i,
  input  logic [2047:0] framebuffer_i,
  output logic          de_o,
  output logic          hsync_o,
  output logic          vsync_o,
  output logic [5:0]    rgb_r_o,
  output logic [5:0]    rgb_g_o,
  output logic [5:0]    rgb_b_o,
  output logic          frame_done_o,
  output logic          vblank_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [11:0] x;
  logic [11:0] y;
  logic active;
  logic chip_active;
  logic [5:0] chip_x;
  logic [4:0] chip_y;
  logic pixel;

  chip8_video_timing #(
    .H_ACTIVE(H_ACTIVE),
    .V_ACTIVE(V_ACTIVE)
  ) u_timing (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(enable_i),
    .x_o(x),
    .y_o(y),
    .active_o(active),
    .hsync_o(hsync_o),
    .vsync_o(vsync_o),
    .vblank_o(vblank_o),
    .frame_done_o(frame_done_o)
  );

  chip8_video_scaler #(
    .TARGET_W(H_ACTIVE),
    .TARGET_H(V_ACTIVE),
    .SCALE(SCALE),
    .X_OFFSET(X_OFFSET),
    .Y_OFFSET(Y_OFFSET)
  ) u_scaler (
    .x_i(x),
    .y_i(y),
    .scale_cfg_i(scale_cfg_i),
    .active_o(chip_active),
    .chip8_x_o(chip_x),
    .chip8_y_o(chip_y)
  );

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign pixel   = chip_active && (framebuffer_i[{chip_y, chip_x}] ^ invert_i)
    ;
  assign de_o    = active;
  assign rgb_r_o = (active && pixel) ? 6'h3f : 6'h00;
  assign rgb_g_o = (active && pixel) ? 6'h3f : 6'h00;
  assign rgb_b_o = (active && pixel) ? 6'h3f : 6'h00;
endmodule

`default_nettype wire

// EOF

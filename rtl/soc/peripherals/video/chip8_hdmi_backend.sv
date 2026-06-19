// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_hdmi_backend.sv
// -----------------------------------------------------------------------------
// @brief HDMI scanout backend.
// =============================================================================
//
// Responsibilities:
// - Convert framebuffer pixels into TMDS video output.
// - Keep scan timing and pixel selection separate.
// - Expose a simple HDMI-compatible output contract.
//
// Characteristics:
// - Backend adapter around the timing and encoder blocks.
// - Pure scanout glue with no architectural state.
// - Used by the board wrappers for video output.
//
// Design notes:
// - Keep pixel gating and color encoding named.
// =============================================================================
`default_nettype none

module chip8_hdmi_backend #(
  parameter int SCALE = 10,
  parameter int X_OFFSET = 0,
  parameter int Y_OFFSET = 80
) (
  input  logic          clk_i,
  input  logic          rst_ni,
  input  logic          enable_i,
  input  logic [7:0]    scale_cfg_i,
  input  logic          invert_i,
  input  logic [2047:0] framebuffer_i,
  output logic          frame_done_o,
  output logic          vblank_o,
  output logic          hdmi_clk_po,
  output logic          hdmi_clk_no,
  output logic [2:0]    hdmi_data_po,
  output logic [2:0]    hdmi_data_no
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] HDMI_PIXEL_OFF = 8'h00;
  localparam logic [7:0] HDMI_PIXEL_ON = 8'hff;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [11:0] x;
  logic [11:0] y;
  logic active;
  logic hsync;
  logic vsync;
  logic chip_active;
  logic [5:0] chip_x;
  logic [4:0] chip_y;
  logic pixel;
  logic [7:0] rgb;
  logic [9:0] tmds_r;
  logic [9:0] tmds_g;
  logic [9:0] tmds_b;

  chip8_video_timing u_timing (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .enable_i(enable_i),
    .x_o(x),
    .y_o(y),
    .active_o(active),
    .hsync_o(hsync),
    .vsync_o(vsync),
    .vblank_o(vblank_o),
    .frame_done_o(frame_done_o)
  );

  chip8_video_scaler #(
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

  assign pixel = chip_active && (framebuffer_i[{chip_y, chip_x}] ^ invert_i);
  assign rgb   = (active && pixel) ? HDMI_PIXEL_ON : HDMI_PIXEL_OFF;

  chip8_tmds_encoder u_b (.de_i(active), .ctrl_i({vsync, hsync}), .data_i(rgb)
    , .encoded_o(tmds_b));
  chip8_tmds_encoder u_g (.de_i(active), .ctrl_i(2'b00), .data_i(rgb),
    .encoded_o(tmds_g));
  chip8_tmds_encoder u_r (.de_i(active), .ctrl_i(2'b00), .data_i(rgb),
    .encoded_o(tmds_r));

  // This portable backend exposes a stable encoded symbol bit for
  // lint/sim.
  // A Tang/Gowin production design should replace this with PLL +
  // serializer.
  assign hdmi_clk_po  = clk_i;
  assign hdmi_clk_no  = ~clk_i;
  assign hdmi_data_po = {tmds_r[0], tmds_g[0], tmds_b[0]};
  assign hdmi_data_no = ~hdmi_data_po;
endmodule

`default_nettype wire

// EOF

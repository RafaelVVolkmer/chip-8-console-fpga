// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_video_scaler.sv
// -----------------------------------------------------------------------------
// @brief Video coordinate scaler.
// =============================================================================
//
// Responsibilities:
// - Map board pixel coordinates to CHIP-8 pixel coordinates.
// - Respect target size, scale and offsets.
// - Keep the active region and edge tests explicit.
//
// Characteristics:
// - Pure combinational coordinate transform.
// - Uses prefix-count helpers for chip-space mapping.
// - Shared by the HDMI and LCD backends.
//
// Design notes:
// - Keep the active window and scale selection named.
// =============================================================================
`default_nettype none

module chip8_video_scaler #(
  parameter int TARGET_W = 640,
  parameter int TARGET_H = 480,
  parameter int SCALE = 10,
  parameter int X_OFFSET = 0,
  parameter int Y_OFFSET = 80
) (
  input  logic [11:0] x_i,
  input  logic [11:0] y_i,
  input  logic [7:0]  scale_cfg_i,
  output logic        active_o,
  output logic [5:0]  chip8_x_o,
  output logic [4:0]  chip8_y_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned X_OFFSET_C = X_OFFSET;
  localparam int unsigned Y_OFFSET_C = Y_OFFSET;
  localparam int unsigned CHIP8_VIDEO_WIDTH = 64;
  localparam int unsigned CHIP8_VIDEO_HEIGHT = 32;
  localparam int unsigned CHIP8_VIDEO_X_SHIFT = 6;
  localparam int unsigned CHIP8_VIDEO_Y_SHIFT = 5;
  localparam int unsigned CHIP8_VIDEO_X_PRED_COUNT =
    CHIP8_VIDEO_WIDTH - 1;
  localparam int unsigned CHIP8_VIDEO_Y_PRED_COUNT =
    CHIP8_VIDEO_HEIGHT - 1;
  localparam logic [7:0] CHIP8_VIDEO_SCALE_AUTO = 8'h00;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [7:0]  scale_eff;
  logic [11:0] rel_x;
  logic [11:0] rel_y;
  logic [31:0] rel_x_ext;
  logic [31:0] rel_y_ext;
  logic [5:0]  chip8_x;
  logic [4:0]  chip8_y;
  logic        in_x;
  logic        in_y;
  logic [31:0] x_ext;
  logic [31:0] y_ext;
  logic [31:0] x_limit;
  logic [31:0] y_limit;
  logic [CHIP8_VIDEO_X_PRED_COUNT-1:0] x_predicates;
  logic [CHIP8_VIDEO_Y_PRED_COUNT-1:0] y_predicates;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign x_ext     = {20'h0, x_i};
  assign y_ext     = {20'h0, y_i};
  assign scale_eff = (scale_cfg_i == CHIP8_VIDEO_SCALE_AUTO) ? SCALE[7:0] :
    scale_cfg_i;
  assign x_limit   = X_OFFSET_C + ({24'h0, scale_eff} <<
    CHIP8_VIDEO_X_SHIFT);
  assign y_limit   = Y_OFFSET_C + ({24'h0, scale_eff} <<
    CHIP8_VIDEO_Y_SHIFT);
  assign in_x      = (x_ext >= X_OFFSET_C) && (x_ext < x_limit);
  assign in_y      = (y_ext >= Y_OFFSET_C) && (y_ext < y_limit);
  assign rel_x_ext = x_ext - X_OFFSET_C;
  assign rel_y_ext = y_ext - Y_OFFSET_C;
  assign rel_x     = rel_x_ext[11:0];
  assign rel_y     = rel_y_ext[11:0];
  assign active_o  = in_x && in_y;
  assign chip8_x_o = active_o ? chip8_x : '0;
  assign chip8_y_o = active_o ? chip8_y : '0;

  chip8_prefix_count #(
    .WIDTH(CHIP8_VIDEO_X_PRED_COUNT),
    .COUNT_WIDTH(6)
  ) u_x_prefix_count (
    .predicates_i(x_predicates),
    .count_o(chip8_x)
  );

  chip8_prefix_count #(
    .WIDTH(CHIP8_VIDEO_Y_PRED_COUNT),
    .COUNT_WIDTH(5)
  ) u_y_prefix_count (
    .predicates_i(y_predicates),
    .count_o(chip8_y)
  );

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    logic [11:0] x_threshold;
    logic [11:0] y_threshold;

    x_threshold = {4'h0, scale_eff};
    y_threshold = {4'h0, scale_eff};
    x_predicates = '0;
    y_predicates = '0;

    // Coordinate scaling is encoded as predicate accumulation instead of
    // iterative overwrite. Each comparator becomes an independent lane and
    // the shared prefix counter owns the reduction/fanout shape.
    // Ref: Ladner/Fischer, parallel prefix computation, JACM, 1980.
    for (int unsigned x_idx = 1; x_idx < CHIP8_VIDEO_WIDTH; x_idx++) begin
      x_predicates[x_idx-1] = rel_x >= x_threshold;
      x_threshold = x_threshold + {4'h0, scale_eff};
    end

    for (int unsigned y_idx = 1; y_idx < CHIP8_VIDEO_HEIGHT; y_idx++) begin
      y_predicates[y_idx-1] = rel_y >= y_threshold;
      y_threshold = y_threshold + {4'h0, scale_eff};
    end
  end
endmodule

`default_nettype wire

// EOF

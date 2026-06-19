// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_video_scanout.sv
// -----------------------------------------------------------------------------
// @brief Video Video scanout.
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

module chip8_video_scanout (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [2047:0] framebuffer_i,
  output logic        valid_o,
  output logic [5:0]  x_o,
  output logic [4:0]  y_o,
  output logic        pixel_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [5:0] CHIP8_SCANOUT_LAST_X = 6'd63;
  localparam logic [4:0] CHIP8_SCANOUT_LAST_Y = 5'd31;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        valid_q;
  logic        valid_d;
  logic [5:0]  x_q;
  logic [5:0]  x_d;
  logic [4:0]  y_q;
  logic [4:0]  y_d;
  logic        pixel_q;
  logic        pixel_d;
  logic [10:0] pixel_index;
  logic x_wrap;
  logic y_wrap;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign pixel_index = {y_q, 6'h00} + {5'h00, x_q};
  assign x_wrap = x_q == CHIP8_SCANOUT_LAST_X;
  assign y_wrap = y_q == CHIP8_SCANOUT_LAST_Y;
  assign valid_d = '1;
  assign pixel_d = framebuffer_i[pixel_index];
  assign x_d = x_wrap ? '0 : x_q + 1'b1;
  assign y_d = x_wrap ? (y_wrap ? '0 : y_q + 1'b1) : y_q;
  assign valid_o = valid_q;
  assign x_o = x_q;
  assign y_o = y_q;
  assign pixel_o = pixel_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= '0;
      x_q <= '0;
      y_q <= '0;
      pixel_q <= '0;
    end else begin
      valid_q <= valid_d;
      x_q <= x_d;
      y_q <= y_d;
      pixel_q <= pixel_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert(x_o <= CHIP8_SCANOUT_LAST_X);
      assert(y_o <= CHIP8_SCANOUT_LAST_Y);
    end
  end
`endif
endmodule

`default_nettype wire

// EOF

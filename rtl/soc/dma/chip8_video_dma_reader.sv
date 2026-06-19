// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_video_dma_reader.sv
// -----------------------------------------------------------------------------
// @brief Video DMA scanout reader.
// =============================================================================
//
// Responsibilities:
// - Stream framebuffer pixels out for scanout or checks.
// - Keep pixel coordinates and frame boundaries explicit.
// - Support video validation and backend feeding.
//
// Characteristics:
// - Sequential scan helper.
// - Consumes packed framebuffer state.
// - Matches the CHIP-8 display geometry.
//
// Design notes:
// - Keep the scanout width and height named.
// =============================================================================
`default_nettype none

module chip8_video_dma_reader #(
  parameter int FB_WIDTH = 64,
  parameter int FB_HEIGHT = 32,
  parameter int FB_BITS = FB_WIDTH * FB_HEIGHT
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              enable_i,
  input  logic              restart_i,
  input  logic [FB_BITS-1:0] framebuffer_i,
  output logic              pixel_valid_o,
  output logic [5:0]        pixel_x_o,
  output logic [4:0]        pixel_y_o,
  output logic              pixel_o,
  output logic              frame_done_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned LAST_INDEX = FB_BITS - 1;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [31:0] index_q;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign pixel_valid_o = enable_i;
  assign pixel_x_o     = index_q[5:0];
  assign pixel_y_o     = index_q[10:6];
  assign pixel_o       = framebuffer_i[index_q];

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : video_dma_reader_ff
    if (!rst_ni) begin
      index_q      <= '0;
      frame_done_o <= '0;
    end else begin
      frame_done_o <= '0;
      if (!enable_i || restart_i) begin
        index_q <= '0;
      end else if (index_q == LAST_INDEX) begin
        index_q      <= '0;
        frame_done_o <= '1;
      end else begin
        index_q <= index_q + 1'b1;
      end
    end
  end
endmodule

`default_nettype wire

// EOF

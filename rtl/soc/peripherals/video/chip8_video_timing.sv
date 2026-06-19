// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_video_timing.sv
// -----------------------------------------------------------------------------
// @brief Video timing generator.
// =============================================================================
//
// Responsibilities:
// - Generate scan coordinates, sync and frame timing.
// - Keep active, blanking and frame-done behavior visible.
// - Provide the backbone for all video backends.
//
// Characteristics:
// - Synchronous timing state machine.
// - Used by the display backends and formal proofs.
// - Board-specific clocks stay outside the block.
//
// Design notes:
// - Keep the visible and blanking intervals named.
// =============================================================================
`default_nettype none

module chip8_video_timing #(
  parameter int H_ACTIVE = 640,
  parameter int H_FRONT  = 16,
  parameter int H_SYNC   = 96,
  parameter int H_BACK   = 48,
  parameter int V_ACTIVE = 480,
  parameter int V_FRONT  = 10,
  parameter int V_SYNC   = 2,
  parameter int V_BACK   = 33
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        enable_i,
  output logic [11:0] x_o,
  output logic [11:0] y_o,
  output logic        active_o,
  output logic        hsync_o,
  output logic        vsync_o,
  output logic        vblank_o,
  output logic        frame_done_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
  localparam int unsigned V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
  localparam int unsigned H_SYNC_BEGIN = H_ACTIVE + H_FRONT;
  localparam int unsigned H_SYNC_END = H_ACTIVE + H_FRONT + H_SYNC;
  localparam int unsigned V_SYNC_BEGIN = V_ACTIVE + V_FRONT;
  localparam int unsigned V_SYNC_END = V_ACTIVE + V_FRONT + V_SYNC;
  localparam int unsigned H_LAST = H_TOTAL - 1;
  localparam int unsigned V_LAST = V_TOTAL - 1;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [31:0] x_q;
  logic [31:0] y_q;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign x_o        = x_q[11:0];
  assign y_o        = y_q[11:0];
  assign active_o   = (x_q < H_ACTIVE) && (y_q < V_ACTIVE);
  assign hsync_o    = (x_q >= H_SYNC_BEGIN) && (x_q < H_SYNC_END);
  assign vsync_o    = (y_q >= V_SYNC_BEGIN) && (y_q < V_SYNC_END);
  assign vblank_o   = (y_q >= V_ACTIVE);

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : video_timing_ff
    if (!rst_ni) begin
      x_q          <= '0;
      y_q          <= '0;
      frame_done_o <= '0;
    end else begin
      frame_done_o <= '0;
      if (!enable_i) begin
        x_q <= '0;
        y_q <= '0;
      end else if (x_q == H_LAST) begin
        x_q <= '0;
        if (y_q == V_LAST) begin
          y_q          <= '0;
          frame_done_o <= '1;
        end else begin
          y_q <= y_q + 1'b1;
        end
      end else begin
        x_q <= x_q + 1'b1;
      end
    end
  end
endmodule

`default_nettype wire

// EOF

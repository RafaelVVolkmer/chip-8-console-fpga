// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_pulse_sync.sv
// -----------------------------------------------------------------------------
// @brief Pulse synchronizer.
// =============================================================================
//
// Responsibilities:
// - Transfer a pulse between unrelated clock domains.
// - Stretch or acknowledge the event as needed.
// - Avoid missing short events across the CDC boundary.
//
// Characteristics:
// - Event-level CDC primitive.
// - Built from synchronizer-safe control.
// - Useful for IRQs and one-shot notifications.
//
// Design notes:
// - Keep the toggle/ack contract explicit.
// =============================================================================
`default_nettype none

module chip8_pulse_sync (
  input  logic src_clk_i,
  input  logic src_rst_ni,
  input  logic src_pulse_i,
  input  logic dst_clk_i,
  input  logic dst_rst_ni,
  output logic dst_pulse_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic src_toggle_q;
  logic src_toggle_d;
  logic dst_toggle_sync;
  logic dst_toggle_q;
  logic dst_toggle_d;
  logic dst_pulse_q;
  logic dst_pulse_d;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign src_toggle_d = src_toggle_q ^ src_pulse_i;
  assign dst_toggle_d = dst_toggle_sync;
  assign dst_pulse_d = dst_toggle_sync ^ dst_toggle_q;
  assign dst_pulse_o = dst_pulse_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge src_clk_i or negedge src_rst_ni) begin
    if (!src_rst_ni) begin
      src_toggle_q <= '0;
    end else begin
      src_toggle_q <= src_toggle_d;
    end
  end

  chip8_sync_2ff #(
    .WIDTH(1),
    .SYNC_RESET_LEVEL(1'b0)
  ) u_sync (
    .clk_i(dst_clk_i),
    .rst_ni(dst_rst_ni),
    .async_i(src_toggle_q),
    .sync_o(dst_toggle_sync)
  );

  always_ff @(posedge dst_clk_i or negedge dst_rst_ni) begin
    if (!dst_rst_ni) begin
      dst_toggle_q <= '0;
      dst_pulse_q <= '0;
    end else begin
      dst_toggle_q <= dst_toggle_d;
      dst_pulse_q <= dst_pulse_d;
    end
  end
endmodule

`default_nettype wire

// EOF

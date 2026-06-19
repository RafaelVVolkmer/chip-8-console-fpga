// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_sync_2ff.sv
// -----------------------------------------------------------------------------
// @brief Two-flop synchronizer.
// =============================================================================
//
// Responsibilities:
// - Resynchronize a single bit into the destination clock domain.
// - Provide a predictable CDC boundary for flags.
// - Keep metastability mitigation isolated.
//
// Characteristics:
// - One-bit CDC helper.
// - Two registered stages only.
// - Used for reset, interrupts and pulses.
//
// Design notes:
// - Keep the destination-domain sample path obvious.
// =============================================================================
`default_nettype none

module chip8_sync_2ff #(
  parameter int WIDTH = 1,
  parameter logic [WIDTH-1:0] SYNC_RESET_LEVEL = '0
) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic [WIDTH-1:0] async_i,
  output logic [WIDTH-1:0] sync_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [WIDTH-1:0] sync0_q;
  logic [WIDTH-1:0] sync0_d;
  logic [WIDTH-1:0] sync1_q;
  logic [WIDTH-1:0] sync1_d;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign sync0_d = async_i;
  assign sync1_d = sync0_q;
  assign sync_o = sync1_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sync0_q <= SYNC_RESET_LEVEL;
      sync1_q <= SYNC_RESET_LEVEL;
    end else begin
      sync0_q <= sync0_d;
      sync1_q <= sync1_d;
    end
  end
endmodule

`default_nettype wire

// EOF

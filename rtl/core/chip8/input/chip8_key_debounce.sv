// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_key_debounce.sv
// -----------------------------------------------------------------------------
// @brief Keypad/input Key debounce.
// =============================================================================
//
// Responsibilities:
// - Debounce, synchronize or expose keypad state.
// - Keep human-input timing separate from CPU state.
// - Present a clean interface to the system bus.
//
// Characteristics:
// - Input-path helper or peripheral.
// - Uses explicit bitmaps, counters or synchronizers.
// - Shared by local and remote keypad flows.
//
// Design notes:
// - Keep key bitmaps and scan phases named.
// =============================================================================
`default_nettype none

module chip8_key_debounce (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [15:0] keys_i,
  output logic [15:0] keys_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [15:0] prev_keys_q;
  logic [15:0] prev_keys_d;
  logic [15:0] keys_q;
  logic [15:0] keys_d;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign prev_keys_d = keys_i;
  assign keys_d = prev_keys_q & keys_i;
  assign keys_o = keys_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      prev_keys_q <= '0;
      keys_q <= '0;
    end else begin
      prev_keys_q <= prev_keys_d;
      keys_q <= keys_d;
    end
  end
endmodule

`default_nettype wire

// EOF

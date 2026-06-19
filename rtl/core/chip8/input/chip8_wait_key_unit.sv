// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_wait_key_unit.sv
// -----------------------------------------------------------------------------
// @brief Keypad/input Wait key unit.
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

module chip8_wait_key_unit (
  input  logic [15:0] keys_i,
  output logic        any_pressed_o,
  output logic [3:0]  first_pressed_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [15:0] first_onehot;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign any_pressed_o = keys_i != '0;
  assign first_onehot = keys_i & (~keys_i + 1'b1);
  assign first_pressed_o[0] = |(first_onehot & 16'haaaa);
  assign first_pressed_o[1] = |(first_onehot & 16'hcccc);
  assign first_pressed_o[2] = |(first_onehot & 16'hf0f0);
  assign first_pressed_o[3] = |(first_onehot & 16'hff00);
endmodule

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_keypad.sv
// -----------------------------------------------------------------------------
// @brief Keypad/input Keypad.
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

module chip8_keypad (
  input  logic [15:0] keys_i,
  input  logic [3:0]  select_i,
  output logic        selected_pressed_o,
  output logic        any_pressed_o,
  output logic [3:0]  first_pressed_o,
  output logic [15:0] keys_o
);
  chip8_wait_key_unit u_wait_key (
    .keys_i(keys_i),
    .any_pressed_o(any_pressed_o),
    .first_pressed_o(first_pressed_o)
  );

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign selected_pressed_o = keys_i[select_i];
  assign keys_o = keys_i;
endmodule

`default_nettype wire

// EOF

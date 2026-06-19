// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_keypad_if.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Keypad if.
// =============================================================================
//
// Responsibilities:
// - Instantiate the DUT and constrain reset and legal inputs.
// - Assert interface contracts and temporal properties.
// - Keep proof-only state local to the harness.
//
// Characteristics:
// - Non-synthesizable proof wrapper.
// - Uses anyseq/anyconst stimuli and assertions.
// - Intended for bounded or induction proofs.
//
// Design notes:
// - Keep assumptions minimal and assertions local.
// =============================================================================
`default_nettype none

interface chip8_keypad_if;
  // ------------------------------------------------------------
  // Interface signals
  // ------------------------------------------------------------

  logic [15:0] keys;
  logic [3:0]  select;
  logic        selected_pressed;
  logic        any_pressed;
  logic [3:0]  first_pressed;

  // ------------------------------------------------------------
  // Modports
  // ------------------------------------------------------------

  modport cpu (output select, input keys, input selected_pressed,
    input any_pressed, input first_pressed);
  modport device (input select, input keys, output selected_pressed,
    output any_pressed, output first_pressed);
endinterface

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_io_mux.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Io mux.
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

module chip8_io_mux (
  input  logic [3:0]  addr_i,
  input  logic [7:0]  delay_i,
  input  logic [7:0]  sound_i,
  input  logic [15:0] keys_i,
  input  logic        key_any_i,
  input  logic [3:0]  key_first_i,
  output logic [7:0]  rdata_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic sel_delay;
  logic sel_sound;
  logic sel_keys_lo;
  logic sel_keys_hi;
  logic sel_key_any;
  logic sel_key_first;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign sel_delay = addr_i == chip8_periph_pkg::CHIP8_IO_DELAY;
  assign sel_sound = addr_i == chip8_periph_pkg::CHIP8_IO_SOUND;
  assign sel_keys_lo = addr_i == chip8_periph_pkg::CHIP8_IO_KEYS_LO;
  assign sel_keys_hi = addr_i == chip8_periph_pkg::CHIP8_IO_KEYS_HI;
  assign sel_key_any = addr_i == chip8_periph_pkg::CHIP8_IO_KEY_ANY;
  assign sel_key_first = addr_i == chip8_periph_pkg::CHIP8_IO_KEY_FIRST;

  assign rdata_o =
    ({8{sel_delay}} & delay_i) |
    ({8{sel_sound}} & sound_i) |
    ({8{sel_keys_lo}} & keys_i[7:0]) |
    ({8{sel_keys_hi}} & keys_i[15:8]) |
    ({8{sel_key_any}} & {7'h00, key_any_i}) |
    ({8{sel_key_first}} & {4'h0, key_first_i});
endmodule

`default_nettype wire

// EOF

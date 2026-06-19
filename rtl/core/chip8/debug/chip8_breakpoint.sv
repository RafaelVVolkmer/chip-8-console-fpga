// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_breakpoint.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Breakpoint.
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

module chip8_breakpoint (
  input  logic        enable_i,
  input  logic [11:0] pc_i,
  input  logic [11:0] break_pc_i,
  output logic        hit_o
);
  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign hit_o = enable_i && pc_i == break_pc_i;
endmodule

`default_nettype wire

// EOF

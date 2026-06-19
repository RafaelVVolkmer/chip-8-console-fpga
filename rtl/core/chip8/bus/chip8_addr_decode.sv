// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_addr_decode.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Addr decode.
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

module chip8_addr_decode (
  input  logic [11:0] addr_i,
  output logic        mem_sel_o,
  output logic        io_sel_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [11:0] CHIP8_IO_BASE_ADDR = 12'hff0;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign mem_sel_o = addr_i < CHIP8_IO_BASE_ADDR;
  assign io_sel_o = addr_i >= CHIP8_IO_BASE_ADDR;
endmodule

`default_nettype wire

// EOF

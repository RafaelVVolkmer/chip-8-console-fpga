// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_fetch.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 instruction fetch helper.
// =============================================================================
//
// Responsibilities:
// - Build sequential and redirected fetch addresses.
// - Keep byte-lane selection visible to the memory path.
// - Support prefetch and formal fetch invariants.
//
// Characteristics:
// - Pure address-generation logic.
// - Uses explicit ROM/RAM address masks.
// - Keeps fetch timing separate from execution.
//
// Design notes:
// - Prefer explicit masks for every address wrap.
// =============================================================================
`default_nettype none

module chip8_fetch (
  input  logic [11:0] pc_i,
  input  logic [7:0]  mem_hi_i,
  input  logic [7:0]  mem_lo_i,
  output logic [11:0] raddr_hi_o,
  output logic [11:0] raddr_lo_o,
  output logic [15:0] opcode_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [11:0] CHIP8_FETCH_ADDR_MASK = 12'hfff;
  localparam logic [11:0] CHIP8_FETCH_LOW_BYTE_OFFSET = 12'd1;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign raddr_hi_o = pc_i;
  assign raddr_lo_o = (pc_i + CHIP8_FETCH_LOW_BYTE_OFFSET) &
    CHIP8_FETCH_ADDR_MASK;
  assign opcode_o = {mem_hi_i, mem_lo_i};
endmodule

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_skip_unit.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 skip-condition unit.
// =============================================================================
//
// Responsibilities:
// - Evaluate conditional skip opcodes only.
// - Keep equality and inequality tests local.
// - Return a single combinational skip decision.
//
// Characteristics:
// - Stateless combinational helper.
// - Used by the core control path for branches.
// - Keeps skip semantics separate from PC updates.
//
// Design notes:
// - Name each skip rule after the opcode family it serves.
// =============================================================================
`default_nettype none

module chip8_skip_unit (
  input  logic [3:0] opcode_class_i,
  input  logic [7:0] vx_i,
  input  logic [7:0] vy_i,
  input  logic [7:0] kk_i,
  input  logic [3:0] n_i,
  output logic       skip_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [3:0] CHIP8_SKIP_EQ_IMM_CLASS = 4'h3;
  localparam logic [3:0] CHIP8_SKIP_NE_IMM_CLASS = 4'h4;
  localparam logic [3:0] CHIP8_SKIP_EQ_REG_CLASS = 4'h5;
  localparam logic [3:0] CHIP8_SKIP_NE_REG_CLASS = 4'h9;
  localparam logic [3:0] CHIP8_REG_SKIP_LOW_NIBBLE = 4'h0;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign skip_o =
    (opcode_class_i == CHIP8_SKIP_EQ_IMM_CLASS && vx_i == kk_i) ||
    (opcode_class_i == CHIP8_SKIP_NE_IMM_CLASS && vx_i != kk_i) ||
    (opcode_class_i == CHIP8_SKIP_EQ_REG_CLASS &&
      n_i == CHIP8_REG_SKIP_LOW_NIBBLE && vx_i == vy_i) ||
    (opcode_class_i == CHIP8_SKIP_NE_REG_CLASS &&
      n_i == CHIP8_REG_SKIP_LOW_NIBBLE && vx_i != vy_i);
endmodule

`default_nettype wire

// EOF

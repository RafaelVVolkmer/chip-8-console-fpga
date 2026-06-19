// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_alu.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 ALU.
// =============================================================================
//
// Responsibilities:
// - Execute arithmetic and logic opcodes.
// - Report carry, borrow and shift flags.
// - Keep the opcode mapping one-to-one with the ISA.
//
// Characteristics:
// - Pure combinational operator block.
// - Small control surface, easy to lint and formalize.
// - Shared by core execution and validation.
//
// Design notes:
// - Keep each opcode family mapped to a named operation.
// =============================================================================
`default_nettype none

module chip8_alu (
  input  chip8_alu_pkg::chip8_alu_op_t op_i,
  input  logic [7:0]               a_i,
  input  logic [7:0]               b_i,
  output logic [7:0]               y_o,
  output logic                     flag_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned CHIP8_ALU_DATA_BITS = 8;
  localparam int unsigned CHIP8_ALU_EXTENDED_DATA_BITS =
    CHIP8_ALU_DATA_BITS + 1;
  localparam int unsigned CHIP8_ALU_LSB_INDEX = 0;
  localparam int unsigned CHIP8_ALU_MSB_INDEX = CHIP8_ALU_DATA_BITS - 1;
  localparam logic CHIP8_ALU_ZERO_FILL_BIT = '0;

  localparam int unsigned CHIP8_ALU_MOV_SELECT  = 0;
  localparam int unsigned CHIP8_ALU_OR_SELECT   = 1;
  localparam int unsigned CHIP8_ALU_AND_SELECT  = 2;
  localparam int unsigned CHIP8_ALU_XOR_SELECT  = 3;
  localparam int unsigned CHIP8_ALU_ADD_SELECT  = 4;
  localparam int unsigned CHIP8_ALU_SUB_SELECT  = 5;
  localparam int unsigned CHIP8_ALU_SHR_SELECT  = 6;
  localparam int unsigned CHIP8_ALU_RSUB_SELECT = 7;
  localparam int unsigned CHIP8_ALU_SHL_SELECT  = 8;
  localparam int unsigned CHIP8_ALU_SELECT_COUNT = 9;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [CHIP8_ALU_EXTENDED_DATA_BITS-1:0] sum;
  logic [CHIP8_ALU_DATA_BITS-1:0] sub_y;
  logic [CHIP8_ALU_DATA_BITS-1:0] rsub_y;
  logic [CHIP8_ALU_SELECT_COUNT-1:0] op_sel;
  logic op_default;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign sum =
    {CHIP8_ALU_ZERO_FILL_BIT, a_i} +
    {CHIP8_ALU_ZERO_FILL_BIT, b_i};
  assign sub_y = a_i - b_i;
  assign rsub_y = b_i - a_i;

  assign op_sel[CHIP8_ALU_MOV_SELECT] = op_i == chip8_alu_pkg::CHIP8_ALU_MOV;
  assign op_sel[CHIP8_ALU_OR_SELECT] = op_i == chip8_alu_pkg::CHIP8_ALU_OR;
  assign op_sel[CHIP8_ALU_AND_SELECT] = op_i == chip8_alu_pkg::CHIP8_ALU_AND;
  assign op_sel[CHIP8_ALU_XOR_SELECT] = op_i == chip8_alu_pkg::CHIP8_ALU_XOR;
  assign op_sel[CHIP8_ALU_ADD_SELECT] =
    (op_i == chip8_alu_pkg::CHIP8_ALU_ADD) ||
    (op_i == chip8_alu_pkg::CHIP8_ALU_ADD_IMM);
  assign op_sel[CHIP8_ALU_SUB_SELECT] = op_i == chip8_alu_pkg::CHIP8_ALU_SUB;
  assign op_sel[CHIP8_ALU_SHR_SELECT] = op_i == chip8_alu_pkg::CHIP8_ALU_SHR;
  assign op_sel[CHIP8_ALU_RSUB_SELECT] =
    op_i == chip8_alu_pkg::CHIP8_ALU_RSUB;
  assign op_sel[CHIP8_ALU_SHL_SELECT] = op_i == chip8_alu_pkg::CHIP8_ALU_SHL;
  assign op_default = !(|op_sel);

  // The ALU computes all short CHIP-8 operations in parallel and uses
  // one-hot predicates to select the committed result. This avoids a control
  // branch in the datapath and keeps the flag equation aligned with the data
  // result.
  // Ref: Mahlke et al., predicated execution support, ACM/IEEE ISCA, 1992.
  assign y_o =
    ({CHIP8_ALU_DATA_BITS{op_sel[CHIP8_ALU_MOV_SELECT]}} & b_i) |
    ({CHIP8_ALU_DATA_BITS{op_sel[CHIP8_ALU_OR_SELECT]}} & (a_i | b_i)) |
    ({CHIP8_ALU_DATA_BITS{op_sel[CHIP8_ALU_AND_SELECT]}} & (a_i & b_i)) |
    ({CHIP8_ALU_DATA_BITS{op_sel[CHIP8_ALU_XOR_SELECT]}} & (a_i ^ b_i)) |
    ({CHIP8_ALU_DATA_BITS{op_sel[CHIP8_ALU_ADD_SELECT]}} &
      sum[CHIP8_ALU_MSB_INDEX:CHIP8_ALU_LSB_INDEX]) |
    ({CHIP8_ALU_DATA_BITS{op_sel[CHIP8_ALU_SUB_SELECT]}} & sub_y) |
    ({CHIP8_ALU_DATA_BITS{op_sel[CHIP8_ALU_SHR_SELECT]}} &
      {CHIP8_ALU_ZERO_FILL_BIT, a_i[CHIP8_ALU_MSB_INDEX:1]}) |
    ({CHIP8_ALU_DATA_BITS{op_sel[CHIP8_ALU_RSUB_SELECT]}} & rsub_y) |
    ({CHIP8_ALU_DATA_BITS{op_sel[CHIP8_ALU_SHL_SELECT]}} &
      {a_i[CHIP8_ALU_MSB_INDEX-1:CHIP8_ALU_LSB_INDEX],
       CHIP8_ALU_ZERO_FILL_BIT}) |
    ({CHIP8_ALU_DATA_BITS{op_default}} & a_i);

  assign flag_o =
    (op_sel[CHIP8_ALU_ADD_SELECT] & sum[CHIP8_ALU_DATA_BITS]) |
    (op_sel[CHIP8_ALU_SUB_SELECT] & (a_i >= b_i)) |
    (op_sel[CHIP8_ALU_SHR_SELECT] & a_i[CHIP8_ALU_LSB_INDEX]) |
    (op_sel[CHIP8_ALU_RSUB_SELECT] & (b_i >= a_i)) |
    (op_sel[CHIP8_ALU_SHL_SELECT] & a_i[CHIP8_ALU_MSB_INDEX]);
endmodule

`default_nettype wire

// EOF

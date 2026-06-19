// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_alu_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for shared CHIP-8 Alu pkg definitions.
// =============================================================================
//
// Responsibilities:
// - Centralize compile-time constants, encodings and typedefs.
// - Keep imports decoupled from module internals.
// - Provide a single namespace for downstream blocks.
//
// Characteristics:
// - Pure elaboration-time content only.
// - No state or sequential logic.
// - Used by RTL and formal copies alike.
//
// Design notes:
// - Keep shared encodings small and explicit.
// =============================================================================
`default_nettype none

package chip8_alu_pkg;
  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // ALU operation selected by opcode class 8xy* or immediate-add decode.
  //
  // Responsibilities:
  // - Encodes the arithmetic/logical operation local to chip8_alu.
  // - Keeps flag-producing operations explicit for VF update logic.
  // - Includes ADD_IMM so immediate arithmetic shares the ALU datapath.
  typedef enum logic [3:0] {
    CHIP8_ALU_MOV,
    CHIP8_ALU_OR,
    CHIP8_ALU_AND,
    CHIP8_ALU_XOR,
    CHIP8_ALU_ADD,
    CHIP8_ALU_SUB,
    CHIP8_ALU_SHR,
    CHIP8_ALU_RSUB,
    CHIP8_ALU_SHL,
    CHIP8_ALU_ADD_IMM
  } chip8_alu_op_t;
endpackage

`default_nettype wire

// EOF

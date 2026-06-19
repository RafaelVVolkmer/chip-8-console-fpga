// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_isa_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for shared CHIP-8 Isa pkg definitions.
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

package chip8_isa_pkg;
  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // CHIP-8 primary opcode class, encoded by instruction bits [15:12].
  //
  // Responsibilities:
  // - Names every high-nibble class used by decode and control.
  // - Keeps raw class encodings in one package instead of spreading literals
  //   through the CPU.
  // - Classes with multiple sub-operations are refined by lower opcode fields.
  typedef enum logic [3:0] {
    CHIP8_OP_SYS  = '0,
    CHIP8_OP_JP   = 4'h1,
    CHIP8_OP_CALL = 4'h2,
    CHIP8_OP_SEB  = 4'h3,
    CHIP8_OP_SNEB = 4'h4,
    CHIP8_OP_SER  = 4'h5,
    CHIP8_OP_LDB  = 4'h6,
    CHIP8_OP_ADDB = 4'h7,
    CHIP8_OP_ALU  = 4'h8,
    CHIP8_OP_SNER = 4'h9,
    CHIP8_OP_LDI  = 4'ha,
    CHIP8_OP_JPV0 = 4'hb,
    CHIP8_OP_RND  = 4'hc,
    CHIP8_OP_DRW  = 4'hd,
    CHIP8_OP_KEY  = 4'he,
    CHIP8_OP_MISC = 4'hf
  } chip8_opcode_class_e;
endpackage

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_config_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for shared CHIP-8 Config pkg definitions.
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

/* verilator lint_off UNUSEDPARAM */
package chip8_config_pkg;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int CHIP8_ADDR_WIDTH = 12;
  localparam int CHIP8_DATA_WIDTH = 8;
  localparam int CHIP8_OPCODE_WIDTH = 16;
  localparam int CHIP8_RAM_SIZE = 4096;
  localparam int CHIP8_NUM_REGS = 16;
  localparam int CHIP8_STACK_DEPTH = 16;
  localparam int CHIP8_SCREEN_W = 64;
  localparam int CHIP8_SCREEN_H = 32;
  localparam int CHIP8_SCREEN_PIXELS = CHIP8_SCREEN_W * CHIP8_SCREEN_H;
  localparam int CHIP8_TIMER_HZ = 60;
endpackage
/* verilator lint_on UNUSEDPARAM */

`default_nettype wire

// EOF

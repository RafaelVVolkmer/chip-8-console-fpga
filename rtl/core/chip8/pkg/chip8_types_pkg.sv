// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_types_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for shared CHIP-8 Types pkg definitions.
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

package chip8_types_pkg;
  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // Core address type.
  //
  // Characteristics:
  // - Covers the 4 KiB CHIP-8 address space.
  // - Used for RAM, ROM and index register address paths.
  typedef logic [11:0] chip8_addr_t;

  // Core byte type.
  //
  // Characteristics:
  // - Represents one CHIP-8 memory/register byte.
  // - Used by RAM, ROM loading, timers, display data and peripheral payloads.
  typedef logic [7:0] chip8_byte_t;

  // Core opcode type.
  //
  // Characteristics:
  // - Holds one fetched 16-bit CHIP-8 instruction.
  // - Shared by fetch, decode, trace and control logic.
  typedef logic [15:0] chip8_opcode_t;

  // V-register index type.
  //
  // Characteristics:
  // - Selects one of the sixteen CHIP-8 V registers.
  // - Used for decoded x/y/n register fields and register-file addressing.
  typedef logic [3:0] chip8_reg_idx_t;

  // CHIP-8 display X coordinate type.
  //
  // Characteristics:
  // - Covers horizontal pixel positions 0..63.
  // - Used by draw, scanout and video peripheral paths.
  typedef logic [5:0] chip8_x_t;

  // CHIP-8 display Y coordinate type.
  //
  // Characteristics:
  // - Covers vertical pixel positions 0..31.
  // - Used by draw, scanout and video peripheral paths.
  typedef logic [4:0] chip8_y_t;
endpackage

`default_nettype wire

// EOF

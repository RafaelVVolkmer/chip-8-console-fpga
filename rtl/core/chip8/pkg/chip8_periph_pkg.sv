// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_periph_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for shared CHIP-8 Periph pkg definitions.
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

package chip8_periph_pkg;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  parameter logic [3:0] CHIP8_IO_DELAY = '0;
  parameter logic [3:0] CHIP8_IO_SOUND = 4'h1;
  parameter logic [3:0] CHIP8_IO_KEYS_LO = 4'h2;
  parameter logic [3:0] CHIP8_IO_KEYS_HI = 4'h3;
  parameter logic [3:0] CHIP8_IO_KEY_ANY = 4'h4;
  parameter logic [3:0] CHIP8_IO_KEY_FIRST = 4'h5;
endpackage

`default_nettype wire

// EOF

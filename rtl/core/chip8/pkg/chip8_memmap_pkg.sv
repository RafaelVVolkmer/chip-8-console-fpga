// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_memmap_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for shared CHIP-8 Memmap pkg definitions.
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

package chip8_memmap_pkg;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [11:0] CHIP8_FONT_BASE = '0;
  localparam logic [11:0] CHIP8_FONT_LAST = 12'h04f;
  localparam logic [11:0] CHIP8_ROM_BASE_ADDR = 12'h200;
  localparam logic [11:0] CHIP8_RAM_LAST = 12'hfff;
endpackage

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for shared CHIP-8 Pkg definitions.
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

package chip8_pkg;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  parameter logic [11:0] CHIP8_ROM_BASE = 12'h200;
endpackage

`default_nettype wire

// EOF

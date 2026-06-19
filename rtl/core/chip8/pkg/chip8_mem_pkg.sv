// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_mem_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for shared CHIP-8 Mem pkg definitions.
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
package chip8_mem_pkg;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  parameter int CHIP8_MEM_BYTES = 4096;
endpackage
/* verilator lint_on UNUSEDPARAM */

`default_nettype wire

// EOF

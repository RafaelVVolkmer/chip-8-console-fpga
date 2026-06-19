// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_dma_pkg.sv
// -----------------------------------------------------------------------------
// @brief DMA constants and encodings package.
// =============================================================================
//
// Responsibilities:
// - Define the DMA register and status encodings.
// - Share flag names between RTL and formal code.
// - Avoid duplicating DMA magic numbers across blocks.
//
// Characteristics:
// - Compile-time package only.
// - No state, only constants and type aliases.
// - Used by keypad and video DMA helpers.
//
// Design notes:
// - Keep status bit positions named.
// =============================================================================
`default_nettype none

package chip8_dma_pkg;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int DMA_CTRL_ENABLE = 0;
  localparam int DMA_CTRL_START  = 1;
  localparam int DMA_CTRL_CIRC   = 2;

  localparam int DMA_STATUS_BUSY  = 0;
  localparam int DMA_STATUS_DONE  = 1;
  localparam int DMA_STATUS_ERROR = 2;
endpackage

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_video_if.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Video if.
// =============================================================================
//
// Responsibilities:
// - Instantiate the DUT and constrain reset and legal inputs.
// - Assert interface contracts and temporal properties.
// - Keep proof-only state local to the harness.
//
// Characteristics:
// - Non-synthesizable proof wrapper.
// - Uses anyseq/anyconst stimuli and assertions.
// - Intended for bounded or induction proofs.
//
// Design notes:
// - Keep assumptions minimal and assertions local.
// =============================================================================
`default_nettype none

interface chip8_video_if;
  // ------------------------------------------------------------
  // Interface signals
  // ------------------------------------------------------------

  logic        valid;
  logic [5:0]  x;
  logic [4:0]  y;
  logic        pixel;
  logic [2047:0] framebuffer;

  // ------------------------------------------------------------
  // Modports
  // ------------------------------------------------------------

  modport producer (output valid, output x, output y, output pixel,
    output framebuffer);
  modport consumer (input valid, input x, input y, input pixel,
    input framebuffer);
endinterface

`default_nettype wire

// EOF

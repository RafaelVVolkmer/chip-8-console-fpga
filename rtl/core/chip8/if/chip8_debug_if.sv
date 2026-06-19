// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_debug_if.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Debug if.
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

interface chip8_debug_if;
  // ------------------------------------------------------------
  // Interface signals
  // ------------------------------------------------------------

  logic        valid;
  logic [11:0] pc;
  logic [15:0] opcode;
  logic [2:0]  state;
  logic        halt_req;

  // ------------------------------------------------------------
  // Modports
  // ------------------------------------------------------------

  modport source (output valid, output pc, output opcode, output state,
    input halt_req);
  modport sink   (input valid, input pc, input opcode, input state,
    output halt_req);
endinterface

`default_nettype wire

// EOF

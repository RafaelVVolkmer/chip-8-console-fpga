// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_bus_if.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Bus if.
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

interface chip8_bus_if;
  // ------------------------------------------------------------
  // Interface signals
  // ------------------------------------------------------------

  logic [11:0] addr;
  logic [7:0]  wdata;
  logic [7:0]  rdata;
  logic        we;

  // ------------------------------------------------------------
  // Modports
  // ------------------------------------------------------------

  modport master (output addr, output wdata, output we, input rdata);
  modport slave  (input addr, input wdata, input we, output rdata);
endinterface

`default_nettype wire

// EOF

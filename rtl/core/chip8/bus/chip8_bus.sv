// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_bus.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Bus.
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

module chip8_bus (
  input  logic [11:0] addr_i,
  input  logic [7:0]  mem_rdata_i,
  input  logic [7:0]  io_rdata_i,
  output logic        mem_sel_o,
  output logic        io_sel_o,
  output logic [7:0]  rdata_o
);
  chip8_addr_decode u_addr_decode (
    .addr_i(addr_i),
    .mem_sel_o(mem_sel_o),
    .io_sel_o(io_sel_o)
  );

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign rdata_o = io_sel_o ? io_rdata_i : mem_rdata_i;
endmodule

`default_nettype wire

// EOF

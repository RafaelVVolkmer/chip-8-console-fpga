// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_trace.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 execution trace formatter.
// =============================================================================
//
// Responsibilities:
// - Package architectural state into trace records.
// - Help simulation, debug and validation flows.
// - Keep trace formatting separate from the core.
//
// Characteristics:
// - Observability helper, not a functional block.
// - Consumes CPU state and emits debug-friendly data.
// - Should not perturb architectural behavior.
//
// Design notes:
// - Keep trace fields named after the ISA state they expose.
// =============================================================================
`default_nettype none

module chip8_trace (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        valid_i,
  input  logic [11:0] pc_i,
  input  logic [15:0] opcode_i,
  output logic        valid_o,
  output logic [11:0] pc_o,
  output logic [15:0] opcode_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        valid_q;
  logic        valid_d;
  logic [11:0] pc_q;
  logic [11:0] pc_d;
  logic [15:0] opcode_q;
  logic [15:0] opcode_d;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign valid_d = valid_i;
  assign pc_d = ({12{valid_i}} & pc_i) | ({12{!valid_i}} & pc_q);
  assign opcode_d = ({16{valid_i}} & opcode_i) |
    ({16{!valid_i}} & opcode_q);
  assign valid_o = valid_q;
  assign pc_o = pc_q;
  assign opcode_o = opcode_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= '0;
      pc_q <= '0;
      opcode_q <= '0;
    end else begin
      valid_q <= valid_d;
      pc_q <= pc_d;
      opcode_q <= opcode_d;
    end
  end
endmodule

`default_nettype wire

// EOF

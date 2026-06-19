// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_regfile.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 V-register file.
// =============================================================================
//
// Responsibilities:
// - Store and forward the sixteen CHIP-8 V registers.
// - Provide clean read/write behavior to the CPU core.
// - Expose register state for side-effect units and proofs.
//
// Characteristics:
// - Small byte-wide register bank.
// - Synchronous write path with combinational reads.
// - No hidden architectural state outside the bank.
//
// Design notes:
// - Use named register indices for special cases.
// =============================================================================
`default_nettype none

module chip8_regfile (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic [3:0] x_addr_i,
  input  logic [3:0] y_addr_i,
  input  logic [3:0] dbg_addr_i,
  input  logic       we_i,
  input  logic [3:0] waddr_i,
  input  logic [7:0] wdata_i,
  output logic [7:0] x_data_o,
  output logic [7:0] y_data_o,
  output logic [7:0] dbg_data_o,
  output logic [7:0] v0_data_o,
  output logic [7:0] vf_data_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [127:0] regs_flat;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign x_data_o = regs_flat[{x_addr_i, 3'b000} +: 8];
  assign y_data_o = regs_flat[{y_addr_i, 3'b000} +: 8];
  assign dbg_data_o = regs_flat[{dbg_addr_i, 3'b000} +: 8];
  assign v0_data_o = regs_flat[7:0];
  assign vf_data_o = regs_flat[127:120];

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      regs_flat <= '0;
    end else if (we_i) begin
      regs_flat[{waddr_i, 3'b000} +: 8] <= wdata_i;
    end
  end
endmodule

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_pc.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 program counter helper.
// =============================================================================
//
// Responsibilities:
// - Hold and advance the architectural PC.
// - Apply jump, call and return updates cleanly.
// - Keep wrap semantics visible in the address width.
//
// Characteristics:
// - Synchronous register with simple next-state math.
// - All wraparound is explicit at 4 KiB boundaries.
// - Used by fetch and control logic.
//
// Design notes:
// - Keep PC arithmetic expressed through named masks.
// =============================================================================
`default_nettype none

module chip8_pc (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        we_i,
  input  logic [11:0] pc_d_i,
  output logic [11:0] pc_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [11:0] CHIP8_PC_ADDR_MASK = 12'hfff;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [11:0] pc_q;
  logic [11:0] pc_d;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign pc_d = ({12{we_i}} & (pc_d_i & CHIP8_PC_ADDR_MASK)) |
    ({12{!we_i}} & pc_q);
  assign pc_o = pc_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q <= chip8_pkg::CHIP8_ROM_BASE;
    end else begin
      pc_q <= pc_d;
    end
  end
endmodule

`default_nettype wire

// EOF

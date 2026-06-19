// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_ram.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 RAM primitive.
// =============================================================================
//
// Responsibilities:
// - Infer the main CHIP-8 data memory.
// - Provide byte-addressed read and write access.
// - Keep the memory boundary local and predictable.
//
// Characteristics:
// - Synchronous RAM wrapper.
// - Sized for the 4 KiB CHIP-8 address space.
// - Intentional inference target for FPGA tools.
//
// Design notes:
// - Keep the address width and byte enables explicit.
// =============================================================================
`default_nettype none

module chip8_ram (
  input  logic        clk_i,
  input  logic [11:0] raddr0_i,
  input  logic [11:0] raddr1_i,
  input  logic        we_i,
  input  logic [11:0] waddr_i,
  input  logic [7:0]  wdata_i,
  output logic [7:0]  rdata0_o,
  output logic [7:0]  rdata1_o
);
  (* ram_style = "block", syn_ramstyle = "block_ram" *)
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [7:0] mem_q [0:4095];
  logic [7:0] rdata0_q;
  logic [7:0] rdata0_d;
  logic [7:0] rdata1_q;
  logic [7:0] rdata1_d;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign rdata0_d = mem_q[raddr0_i];
  assign rdata1_d = mem_q[raddr1_i];
  assign rdata0_o = rdata0_q;
  assign rdata1_o = rdata1_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin
    rdata0_q <= rdata0_d;
    rdata1_q <= rdata1_d;
    if (we_i) begin
      mem_q[waddr_i] <= wdata_i;
    end
  end
endmodule

`default_nettype wire

// EOF

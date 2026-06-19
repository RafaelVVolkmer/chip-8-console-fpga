// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_mem_arbiter.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 memory Mem arbiter.
// =============================================================================
//
// Responsibilities:
// - Handle program, ROM, RAM and loader data paths.
// - Keep address windows and arbitration explicit.
// - Use FPGA-friendly synchronous boundaries.
//
// Characteristics:
// - Memory-system component or helper.
// - Matches the 4 KiB CHIP-8 address space.
// - Shared by core and boot flows.
//
// Design notes:
// - Keep every address mask and memory window named.
// =============================================================================
`default_nettype none

module chip8_mem_arbiter (
  input  logic        cpu_we_i,
  input  logic [11:0] cpu_addr_i,
  input  logic [7:0]  cpu_data_i,
  input  logic        loader_we_i,
  input  logic [11:0] loader_addr_i,
  input  logic [7:0]  loader_data_i,
  output logic        mem_we_o,
  output logic [11:0] mem_addr_o,
  output logic [7:0]  mem_data_o
);
  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign mem_we_o = loader_we_i | cpu_we_i;
  assign mem_addr_o = loader_we_i ? loader_addr_i : cpu_addr_i;
  assign mem_data_o = loader_we_i ? loader_data_i : cpu_data_i;

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    assert (mem_we_o == (loader_we_i | cpu_we_i));
    if (loader_we_i) begin
      assert (mem_addr_o == loader_addr_i);
      assert (mem_data_o == loader_data_i);
    end else begin
      assert (mem_addr_o == cpu_addr_i);
      assert (mem_data_o == cpu_data_i);
    end
  end
`endif
endmodule

`default_nettype wire

// EOF

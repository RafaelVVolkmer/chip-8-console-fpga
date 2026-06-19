// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_memory.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 memory system.
// =============================================================================
//
// Responsibilities:
// - Route CPU and loader accesses into the memory map.
// - Keep RAM, ROM and peripheral windows explicit.
// - Preserve synchronous FPGA-friendly read/write behavior.
//
// Characteristics:
// - Integration shell for the memory subsystem.
// - Combines map decode, arbitration and storage blocks.
// - No architectural state beyond wiring and control.
//
// Design notes:
// - Name every memory window and arbitration rule.
// =============================================================================
`default_nettype none

module chip8_memory (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [11:0] raddr0_i,
  input  logic [11:0] raddr1_i,
  input  logic        we_i,
  input  logic [11:0] waddr_i,
  input  logic [7:0]  wdata_i,
  output logic [7:0]  rdata0_o,
  output logic [7:0]  rdata1_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [7:0] ram_rdata0;
  logic [7:0] ram_rdata1;
  logic [7:0] font_rdata0;
  logic [7:0] font_rdata1;
  logic is_font0;
  logic is_font1;
  logic is_font0_q;
  logic is_font1_q;
  logic [7:0] font_rdata0_q;
  logic [7:0] font_rdata1_q;
  logic program_unused0;
  logic program_unused1;
  logic write_ready_unused;
  logic elastic_we;
  logic [19:0] elastic_write;

  // ------------------------------------------------------------
  // Elastic write pipeline
  // ------------------------------------------------------------

  chip8_skid_buffer #(
    .DATA_WIDTH(20)
  ) u_write_skid (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .in_valid_i(we_i),
    .in_ready_o(write_ready_unused),
    .in_data_i({waddr_i, wdata_i}),
    .out_valid_o(elastic_we),
    .out_ready_i(1'b1),
    .out_data_o(elastic_write)
  );

  // ------------------------------------------------------------
  // Submodule instances
  // ------------------------------------------------------------

  chip8_ram u_ram (
    .clk_i(clk_i),
    .raddr0_i(raddr0_i),
    .raddr1_i(raddr1_i),
    .we_i(elastic_we),
    .waddr_i(elastic_write[19:8]),
    .wdata_i(elastic_write[7:0]),
    .rdata0_o(ram_rdata0),
    .rdata1_o(ram_rdata1)
  );

  chip8_font_rom u_font0 (
    .addr_i(raddr0_i[6:0]),
    .data_o(font_rdata0)
  );

  chip8_font_rom u_font1 (
    .addr_i(raddr1_i[6:0]),
    .data_o(font_rdata1)
  );

  chip8_memory_map u_map0 (
    .addr_i(raddr0_i),
    .is_font_o(is_font0),
    .is_program_o(program_unused0)
  );

  chip8_memory_map u_map1 (
    .addr_i(raddr1_i),
    .is_font_o(is_font1),
    .is_program_o(program_unused1)
  );

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin
    is_font0_q <= is_font0;
    is_font1_q <= is_font1;
    font_rdata0_q <= font_rdata0;
    font_rdata1_q <= font_rdata1;
  end

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign rdata0_o = (is_font0_q ? font_rdata0_q : ram_rdata0) | {8{(
    program_unused0 | program_unused1) & 1'b0}};
  assign rdata1_o = (is_font1_q ? font_rdata1_q : ram_rdata1) | {8{(
    program_unused0 | program_unused1) & 1'b0}};

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_comb begin
    assert (write_ready_unused);
  end
`endif
endmodule

`default_nettype wire

// EOF

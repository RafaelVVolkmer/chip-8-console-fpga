// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_mem_burst.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 memory burst helper.
// =============================================================================
//
// Responsibilities:
// - Generate sequential memory addresses for burst transfers.
// - Keep burst length and wrap behavior visible to the CPU.
// - Support load/store and draw-data streaming.
//
// Characteristics:
// - Compact helper with explicit address width control.
// - Used where repeated byte writes are required.
// - Matches the 4 KiB CHIP-8 memory map.
//
// Design notes:
// - Name every wrap mask used by burst arithmetic.
// =============================================================================
`default_nettype none

module chip8_mem_burst (
  input  logic        store_i,
  input  logic        load_commit_i,
  input  logic [11:0] index_reg_i,
  input  logic [3:0]  burst_idx_i,
  input  logic [3:0]  saved_x_i,
  input  logic [7:0]  reg_data_i,
  input  logic [7:0]  mem_data_i,
  output logic        mem_we_o,
  output logic [11:0] mem_waddr_o,
  output logic [7:0]  mem_wdata_o,
  output logic        v_we_o,
  output logic [3:0]  v_waddr_o,
  output logic [7:0]  v_wdata_o,
  output logic [3:0]  burst_idx_d_o,
  output chip8_core_pkg::chip8_state_t state_d_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [11:0] CHIP8_MEM_BURST_ADDR_MASK = 12'hfff;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic burst_done;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign burst_done = burst_idx_i == saved_x_i;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    mem_we_o = '0;
    mem_waddr_o = (index_reg_i + {8'h00, burst_idx_i}) &
      CHIP8_MEM_BURST_ADDR_MASK;
    mem_wdata_o = reg_data_i;
    v_we_o = '0;
    v_waddr_o = burst_idx_i;
    v_wdata_o = mem_data_i;
    burst_idx_d_o = burst_done ? burst_idx_i : burst_idx_i + 1'b1;
    state_d_o = burst_done ?
      chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH :
      chip8_core_pkg::CHIP8_CORE_PKG_STATE_STORE;

    if (store_i) begin
      mem_we_o = '1;
      state_d_o = burst_done ?
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH :
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_STORE;
    end else if (load_commit_i) begin
      v_we_o = '1;
      state_d_o = burst_done ?
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH :
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_LOAD;
    end else begin
      burst_idx_d_o = burst_idx_i;
      state_d_o = chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
    end
  end
endmodule

`default_nettype wire

// EOF

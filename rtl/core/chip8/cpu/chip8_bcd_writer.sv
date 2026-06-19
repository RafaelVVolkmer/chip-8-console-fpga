// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_bcd_writer.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 BCD write sequencer.
// =============================================================================
//
// Responsibilities:
// - Stream BCD digits into memory for `Fx33`.
// - Gate writes behind the memory handshake.
// - Keep the three-byte write path visible.
//
// Characteristics:
// - Small sequencer with byte-by-byte output.
// - Uses explicit address masking and byte offsets.
// - Pairs with the BCD converter helper.
//
// Design notes:
// - Use named offsets for hundreds, tens and ones.
// =============================================================================
`default_nettype none

module chip8_bcd_writer (
  input  chip8_core_pkg::chip8_state_t state_i,
  input  logic [11:0] index_reg_i,
  input  logic [3:0]  hundreds_i,
  input  logic [3:0]  tens_i,
  input  logic [3:0]  ones_i,
  output logic        mem_we_o,
  output logic [11:0] mem_waddr_o,
  output logic [7:0]  mem_wdata_o,
  output chip8_core_pkg::chip8_state_t state_d_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [11:0] CHIP8_BCD_ADDR_MASK = 12'hfff;
  localparam logic [11:0] CHIP8_BCD_HUNDREDS_OFFSET = 12'd0;
  localparam logic [11:0] CHIP8_BCD_TENS_OFFSET = 12'd1;
  localparam logic [11:0] CHIP8_BCD_ONES_OFFSET = 12'd2;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    mem_we_o = '1;
    mem_waddr_o = (index_reg_i + CHIP8_BCD_HUNDREDS_OFFSET) &
      CHIP8_BCD_ADDR_MASK;
    mem_wdata_o = {4'h0, hundreds_i};
    state_d_o = chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD1;

    unique case (state_i)
      chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD0: begin
        mem_waddr_o = (index_reg_i + CHIP8_BCD_HUNDREDS_OFFSET) &
          CHIP8_BCD_ADDR_MASK;
        mem_wdata_o = {4'h0, hundreds_i};
        state_d_o = chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD1;
      end
      chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD1: begin
        mem_waddr_o = (index_reg_i + CHIP8_BCD_TENS_OFFSET) &
          CHIP8_BCD_ADDR_MASK;
        mem_wdata_o = {4'h0, tens_i};
        state_d_o = chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD2;
      end
      chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD2: begin
        mem_waddr_o = (index_reg_i + CHIP8_BCD_ONES_OFFSET) &
          CHIP8_BCD_ADDR_MASK;
        mem_wdata_o = {4'h0, ones_i};
        state_d_o = chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
      end
      default: begin
        mem_we_o = '0;
        mem_waddr_o = '0;
        mem_wdata_o = '0;
        state_d_o = chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
      end
    endcase
  end
endmodule

`default_nettype wire

// EOF

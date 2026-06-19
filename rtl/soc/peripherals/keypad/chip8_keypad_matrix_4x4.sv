// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_keypad_matrix_4x4.sv
// -----------------------------------------------------------------------------
// @brief 4x4 keypad matrix scanner.
// =============================================================================
//
// Responsibilities:
// - Drive and sample a 4x4 keypad matrix.
// - Keep row/column scanning visible to the peripheral.
// - Preserve a simple interface for the CPU side.
//
// Characteristics:
// - Pure keypad scanning logic.
// - Matches the CHIP-8 16-key layout.
// - Used by both local and remote keypad paths.
//
// Design notes:
// - Name the row and column scan phases explicitly.
// =============================================================================
`default_nettype none

module chip8_keypad_matrix_4x4 #(
  parameter int CLK_HZ = 27_000_000,
  parameter int SCAN_HZ = 1_000,
  parameter bit ACTIVE_LOW = 1'b1
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        enable_i,
  output logic [3:0]  rows_o,
  input  logic [3:0]  cols_i,
  output logic [15:0] key_bitmap_o,
  output logic        scan_tick_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int DIVISOR = (CLK_HZ / (SCAN_HZ * 4)) < 1 ? 1 : (CLK_HZ / (
    SCAN_HZ * 4));
  localparam int unsigned DIVISOR_LAST = DIVISOR - 1;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [31:0] div_q;
  logic [1:0]           row_q;
  logic [3:0]           cols_active;

  // ------------------------------------------------------------
  // Function declarations
  // ------------------------------------------------------------

  function automatic logic [3:0] chip8_code_for(input logic [1:0] row,
    input logic [1:0] col);
    unique case ({row, col})
      4'b00_00: chip8_code_for = 4'h1;
      4'b00_01: chip8_code_for = 4'h2;
      4'b00_10: chip8_code_for = 4'h3;
      4'b00_11: chip8_code_for = 4'hc;
      4'b01_00: chip8_code_for = 4'h4;
      4'b01_01: chip8_code_for = 4'h5;
      4'b01_10: chip8_code_for = 4'h6;
      4'b01_11: chip8_code_for = 4'hd;
      4'b10_00: chip8_code_for = 4'h7;
      4'b10_01: chip8_code_for = 4'h8;
      4'b10_10: chip8_code_for = 4'h9;
      4'b10_11: chip8_code_for = 4'he;
      4'b11_00: chip8_code_for = 4'ha;
      4'b11_01: chip8_code_for = '0;
      4'b11_10: chip8_code_for = 4'hb;
      default:  chip8_code_for = 4'hf;
    endcase
  endfunction

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : row_drive_comb
    rows_o = ACTIVE_LOW ? 4'b1111 : 4'b0000;
    if (enable_i) begin
      if (ACTIVE_LOW) begin
        rows_o[row_q] = '0;
      end else begin
        rows_o[row_q] = '1;
      end
    end
  end

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign cols_active = ACTIVE_LOW ? ~cols_i : cols_i;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : matrix_scan_ff
    if (!rst_ni) begin
      div_q        <= '0;
      row_q        <= '0;
      key_bitmap_o <= '0;
      scan_tick_o  <= '0;
    end else begin
      scan_tick_o <= '0;
      if (!enable_i) begin
        div_q        <= '0;
        row_q        <= '0;
        key_bitmap_o <= '0;
      end else if (div_q == DIVISOR_LAST) begin
        div_q       <= '0;
        scan_tick_o <= '1;

        for (int col = '0; col < 4; col++) begin
          key_bitmap_o[chip8_code_for(row_q, col[1:0])] <=
            cols_active[col];
        end

        row_q <= row_q + 1'b1;
      end else begin
        div_q <= div_q + 1'b1;
      end
    end
  end
endmodule

`default_nettype wire

// EOF

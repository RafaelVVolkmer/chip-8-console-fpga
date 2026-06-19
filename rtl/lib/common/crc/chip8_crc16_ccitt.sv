// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_crc16_ccitt.sv
// -----------------------------------------------------------------------------
// @brief CRC-16/CCITT helper.
// =============================================================================
//
// Responsibilities:
// - Advance the CCITT CRC state over one input byte.
// - Support ROM chunk and DAP framing checks.
// - Keep polynomial math local and transparent.
//
// Characteristics:
// - Combinational CRC step function.
// - Pure helper with no state of its own.
// - Shared by boot and debug protocols.
//
// Design notes:
// - Keep the polynomial and input padding named.
// =============================================================================
`default_nettype none

module chip8_crc16_ccitt (
  input  logic [15:0] crc_i,
  input  logic [7:0]  data_i,
  output logic [15:0] crc_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int unsigned CRC16_CCITT_DATA_BITS = 8;
  localparam logic [7:0] CRC16_CCITT_INPUT_PAD = 8'h00;
  localparam logic [15:0] CRC16_CCITT_POLY = 16'h1021;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [15:0] crc_d;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    crc_d = crc_i ^ {data_i, CRC16_CCITT_INPUT_PAD};
    for (int bit_idx = '0; bit_idx < CRC16_CCITT_DATA_BITS; bit_idx++) begin
      if (crc_d[15]) begin
        crc_d = (crc_d << 1) ^ CRC16_CCITT_POLY;
      end else begin
        crc_d = crc_d << 1;
      end
    end
    crc_o = crc_d;
  end
endmodule

`default_nettype wire

// EOF

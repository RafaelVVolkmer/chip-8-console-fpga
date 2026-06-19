// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_sd_crc16.sv
// -----------------------------------------------------------------------------
// @brief SD data CRC16 helper.
// =============================================================================
//
// Responsibilities:
// - Advance the SD data CRC16 state by one bit.
// - Support block data checks in the SPI host.
// - Keep the polynomial step visible.
//
// Characteristics:
// - Pure combinational CRC step helper.
// - Used only by the SD data path.
// - No sequential state or bus interface.
//
// Design notes:
// - Keep the polynomial and shift direction named.
// =============================================================================
`default_nettype none

module chip8_sd_crc16 (
  input  logic [15:0] crc_i,
  input  logic        bit_i,
  output logic [15:0] crc_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic feedback;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign feedback = bit_i ^ crc_i[15];
  assign crc_o = {crc_i[14:12], crc_i[11] ^ feedback, crc_i[10:5], crc_i[4] ^
    feedback, crc_i[3:0], feedback};
endmodule

`default_nettype wire

// EOF

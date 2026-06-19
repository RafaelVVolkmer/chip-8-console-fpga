// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_sd_crc7.sv
// -----------------------------------------------------------------------------
// @brief SD command CRC7 helper.
// =============================================================================
//
// Responsibilities:
// - Advance the SD command CRC7 state by one bit.
// - Support command framing for the SPI host.
// - Keep the polynomial step visible.
//
// Characteristics:
// - Pure combinational CRC step helper.
// - Used only by the SD command path.
// - No sequential state or bus interface.
//
// Design notes:
// - Keep the polynomial and shift direction named.
// =============================================================================
`default_nettype none

module chip8_sd_crc7 (
  input  logic [6:0] crc_i,
  input  logic       bit_i,
  output logic [6:0] crc_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic feedback;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign feedback = bit_i ^ crc_i[6];
  assign crc_o = {crc_i[5:3], crc_i[2] ^ feedback, crc_i[1:0], feedback};
endmodule

`default_nettype wire

// EOF

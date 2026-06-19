// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_dap_pkg.sv
// -----------------------------------------------------------------------------
// @brief DAP command and status package.
// =============================================================================
//
// Responsibilities:
// - Define the DAP packet constants and status codes.
// - Share protocol encodings between parser and bridge.
// - Avoid duplicated protocol literals.
//
// Characteristics:
// - Compile-time only package.
// - No sequential state or IO wiring.
// - Used by the USB debug transport.
//
// Design notes:
// - Keep command bytes and status bytes named.
// =============================================================================
`default_nettype none

package chip8_dap_pkg;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] DAP_SOF = 8'ha5;
  localparam logic [7:0] DAP_VERSION = 8'h01;
  localparam logic [15:0] DAP_CRC_INIT = 16'hffff;
  localparam int DAP_MAX_PAYLOAD_BYTES = 32;

  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // Debug Access Port command byte carried by each DAP packet.
  //
  // Responsibilities:
  // - Defines the host-to-FPGA command contract.
  // - Separates control, AXI register access and ROM streaming commands.
  // - Keeps packet parser and USB bridge command matching synchronized.
  typedef enum logic [7:0] {
    DAP_CMD_PING = '0,
    DAP_CMD_ID = 8'h01,
    DAP_CMD_UNLOCK = 8'h02,
    DAP_CMD_LOCK = 8'h03,
    DAP_CMD_HOLD_CORE = 8'h04,
    DAP_CMD_READ32 = 8'h10,
    DAP_CMD_WRITE32 = 8'h11,
    DAP_CMD_ROM_BEGIN = 8'h20,
    DAP_CMD_ROM_WRITE = 8'h21,
    DAP_CMD_ROM_PUSH = 8'h22,
    DAP_CMD_ROM_CRC = 8'h23,
    DAP_CMD_GET_STATUS = 8'h30
  } dap_cmd_t;

  // Debug Access Port response status byte returned to the host.
  //
  // Responsibilities:
  // - Reports parser, lock, bus and ROM-transfer failures with stable codes.
  // - Keeps error reporting independent from internal FSM encodings.
  // - Provides a single OK code for successful command completion.
  typedef enum logic [7:0] {
    DAP_STATUS_OK = '0,
    DAP_STATUS_BAD_SOF = 8'h01,
    DAP_STATUS_BAD_VERSION = 8'h02,
    DAP_STATUS_BAD_CRC = 8'h03,
    DAP_STATUS_BAD_LEN = 8'h04,
    DAP_STATUS_BAD_CMD = 8'h05,
    DAP_STATUS_LOCKED = 8'h06,
    DAP_STATUS_BUS_ERROR = 8'h07,
    DAP_STATUS_BUSY = 8'h08,
    DAP_STATUS_BAD_SEQ = 8'h09,
    DAP_STATUS_ROM_CRC = 8'h0a
  } dap_status_t;
endpackage

`default_nettype wire

// EOF

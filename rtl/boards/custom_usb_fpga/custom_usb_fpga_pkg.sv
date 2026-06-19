// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// custom_usb_fpga_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for board-specific custom USB FPGA board definitions.
// =============================================================================
//
// Responsibilities:
// - Carry board constants, pin groups and default parameters.
// - Keep platform values in one import boundary.
// - Avoid hard-coded board assumptions elsewhere.
//
// Characteristics:
// - Compile-time contract only.
// - No sequential logic or IO buffers.
// - Shared by the board top and constraints.
//
// Design notes:
// - Keep board defaults and pin names explicit.
// =============================================================================
`default_nettype none

package custom_usb_fpga_pkg;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int CUSTOM_USB_FPGA_CLK_HZ = 27_000_000;
  localparam int CUSTOM_USB_FPGA_VIDEO_BACKEND = 0;
endpackage

`default_nettype wire

// EOF

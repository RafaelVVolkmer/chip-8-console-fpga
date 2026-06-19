// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_axi_pkg.sv
// -----------------------------------------------------------------------------
// @brief AXI constants and encodings package.
// =============================================================================
//
// Responsibilities:
// - Define SoC bus slave IDs and helper constants.
// - Keep AXI-visible encodings in one namespace.
// - Avoid hard-coded bus values across wrappers.
//
// Characteristics:
// - Compile-time only.
// - Shared by the SoC interconnect and board tops.
// - No sequential logic or module state.
//
// Design notes:
// - Keep slave IDs and map offsets named.
// =============================================================================
`default_nettype none

package chip8_axi_pkg;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int AXI_ADDR_WIDTH = 16;
  localparam int AXI_DATA_WIDTH = 32;
  localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

  localparam logic [7:0] SLAVE_VIDEO  = 8'h10;
  localparam logic [7:0] SLAVE_KEYPAD = 8'h11;
  localparam logic [7:0] SLAVE_DMA    = 8'h12;
  localparam logic [7:0] SLAVE_IRQ    = 8'h13;
  localparam logic [7:0] SLAVE_DEBUG  = 8'h14;
  localparam logic [7:0] SLAVE_SD     = 8'h15;
  localparam logic [7:0] SLAVE_BOOT   = 8'h16;
  localparam logic [7:0] SLAVE_UART   = 8'h17;
  localparam logic [7:0] SLAVE_DMA2D  = 8'h18;
  localparam logic [7:0] SLAVE_DCMIPP = 8'h19;

  localparam int VIDEO_BACKEND_HDMI    = 0;
  localparam int VIDEO_BACKEND_LCD_SPI = 1;
  localparam int VIDEO_BACKEND_LCD_RGB = 2;

  localparam int IRQ_KEYPAD_EVENT     = 0;
  localparam int IRQ_KEYPAD_OVERFLOW  = 1;
  localparam int IRQ_VIDEO_FRAME_DONE = 2;
  localparam int IRQ_VIDEO_VBLANK     = 3;
  localparam int IRQ_VIDEO_ERROR      = 4;
  localparam int IRQ_KEY_DMA_DONE     = 5;
  localparam int IRQ_VIDEO_DMA_DONE   = 6;
  localparam int IRQ_DMA_ERROR        = 7;
  localparam int IRQ_SD_DONE          = 8;
  localparam int IRQ_SD_ERROR         = 9;
  localparam int IRQ_BOOT_DONE        = 10;
  localparam int IRQ_BOOT_ERROR       = 11;
  localparam int IRQ_UART_RX          = 12;
  localparam int IRQ_DMA2D_DONE       = 13;
  localparam int IRQ_DMA2D_ERROR      = 14;
  localparam int IRQ_DCMIPP_FRAME     = 15;
endpackage

`default_nettype wire

// EOF

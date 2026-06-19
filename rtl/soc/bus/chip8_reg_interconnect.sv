// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_reg_interconnect.sv
// -----------------------------------------------------------------------------
// @brief Register interconnect.
// =============================================================================
//
// Responsibilities:
// - Route local register transactions to the selected peripheral.
// - Keep decode and fanout explicit.
// - Expose a compact system-level register fabric.
//
// Characteristics:
// - Pure routing and decode shell.
// - Lives at the SoC integration boundary.
// - No architectural state beyond bus wiring.
//
// Design notes:
// - Keep every slave window named in the decode.
// =============================================================================
`default_nettype none

module chip8_reg_interconnect #(
  parameter int ADDR_WIDTH = chip8_axi_pkg::AXI_ADDR_WIDTH,
  parameter int DATA_WIDTH = chip8_axi_pkg::AXI_DATA_WIDTH,
  parameter int STRB_WIDTH = chip8_axi_pkg::AXI_STRB_WIDTH
) (
  input  logic                  valid_i,
  input  logic                  we_i,
  input  logic [ADDR_WIDTH-1:0] addr_i,
  input  logic [DATA_WIDTH-1:0] wdata_i,
  input  logic [STRB_WIDTH-1:0] wstrb_i,
  output logic                  ready_o,
  output logic [DATA_WIDTH-1:0] rdata_o,

  output logic                  video_valid_o,
  output logic                  video_we_o,
  output logic [7:0]            video_addr_o,
  output logic [DATA_WIDTH-1:0] video_wdata_o,
  output logic [STRB_WIDTH-1:0] video_wstrb_o,
  input  logic                  video_ready_i,
  input  logic [DATA_WIDTH-1:0] video_rdata_i,

  output logic                  keypad_valid_o,
  output logic                  keypad_we_o,
  output logic [7:0]            keypad_addr_o,
  output logic [DATA_WIDTH-1:0] keypad_wdata_o,
  output logic [STRB_WIDTH-1:0] keypad_wstrb_o,
  input  logic                  keypad_ready_i,
  input  logic [DATA_WIDTH-1:0] keypad_rdata_i,

  output logic                  dma_valid_o,
  output logic                  dma_we_o,
  output logic [7:0]            dma_addr_o,
  output logic [DATA_WIDTH-1:0] dma_wdata_o,
  output logic [STRB_WIDTH-1:0] dma_wstrb_o,
  input  logic                  dma_ready_i,
  input  logic [DATA_WIDTH-1:0] dma_rdata_i,

  output logic                  irq_valid_o,
  output logic                  irq_we_o,
  output logic [7:0]            irq_addr_o,
  output logic [DATA_WIDTH-1:0] irq_wdata_o,
  output logic [STRB_WIDTH-1:0] irq_wstrb_o,
  input  logic                  irq_ready_i,
  input  logic [DATA_WIDTH-1:0] irq_rdata_i,

  output logic                  debug_valid_o,
  output logic                  debug_we_o,
  output logic [7:0]            debug_addr_o,
  output logic [DATA_WIDTH-1:0] debug_wdata_o,
  output logic [STRB_WIDTH-1:0] debug_wstrb_o,
  input  logic                  debug_ready_i,
  input  logic [DATA_WIDTH-1:0] debug_rdata_i,

  output logic                  sd_valid_o,
  output logic                  sd_we_o,
  output logic [7:0]            sd_addr_o,
  output logic [DATA_WIDTH-1:0] sd_wdata_o,
  output logic [STRB_WIDTH-1:0] sd_wstrb_o,
  input  logic                  sd_ready_i,
  input  logic [DATA_WIDTH-1:0] sd_rdata_i,

  output logic                  boot_valid_o,
  output logic                  boot_we_o,
  output logic [7:0]            boot_addr_o,
  output logic [DATA_WIDTH-1:0] boot_wdata_o,
  output logic [STRB_WIDTH-1:0] boot_wstrb_o,
  input  logic                  boot_ready_i,
  input  logic [DATA_WIDTH-1:0] boot_rdata_i,

  output logic                  uart_valid_o,
  output logic                  uart_we_o,
  output logic [7:0]            uart_addr_o,
  output logic [DATA_WIDTH-1:0] uart_wdata_o,
  output logic [STRB_WIDTH-1:0] uart_wstrb_o,
  input  logic                  uart_ready_i,
  input  logic [DATA_WIDTH-1:0] uart_rdata_i,

  output logic                  dma2d_valid_o,
  output logic                  dma2d_we_o,
  output logic [7:0]            dma2d_addr_o,
  output logic [DATA_WIDTH-1:0] dma2d_wdata_o,
  output logic [STRB_WIDTH-1:0] dma2d_wstrb_o,
  input  logic                  dma2d_ready_i,
  input  logic [DATA_WIDTH-1:0] dma2d_rdata_i,

  output logic                  dcmipp_valid_o,
  output logic                  dcmipp_we_o,
  output logic [7:0]            dcmipp_addr_o,
  output logic [DATA_WIDTH-1:0] dcmipp_wdata_o,
  output logic [STRB_WIDTH-1:0] dcmipp_wstrb_o,
  input  logic                  dcmipp_ready_i,
  input  logic [DATA_WIDTH-1:0] dcmipp_rdata_i
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [7:0] slave_sel;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign slave_sel = addr_i[15:8];

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : reg_decode_comb
    video_valid_o  = '0;
    keypad_valid_o = '0;
    dma_valid_o    = '0;
    irq_valid_o    = '0;
    debug_valid_o  = '0;
    sd_valid_o     = '0;
    boot_valid_o   = '0;
    uart_valid_o   = '0;
    dma2d_valid_o  = '0;
    dcmipp_valid_o = '0;

    video_we_o     = we_i;
    keypad_we_o    = we_i;
    dma_we_o       = we_i;
    irq_we_o       = we_i;
    debug_we_o     = we_i;
    sd_we_o        = we_i;
    boot_we_o      = we_i;
    uart_we_o      = we_i;
    dma2d_we_o     = we_i;
    dcmipp_we_o    = we_i;

    video_addr_o   = addr_i[7:0];
    keypad_addr_o  = addr_i[7:0];
    dma_addr_o     = addr_i[7:0];
    irq_addr_o     = addr_i[7:0];
    debug_addr_o   = addr_i[7:0];
    sd_addr_o      = addr_i[7:0];
    boot_addr_o    = addr_i[7:0];
    uart_addr_o    = addr_i[7:0];
    dma2d_addr_o   = addr_i[7:0];
    dcmipp_addr_o  = addr_i[7:0];

    video_wdata_o  = wdata_i;
    keypad_wdata_o = wdata_i;
    dma_wdata_o    = wdata_i;
    irq_wdata_o    = wdata_i;
    debug_wdata_o  = wdata_i;
    sd_wdata_o     = wdata_i;
    boot_wdata_o   = wdata_i;
    uart_wdata_o   = wdata_i;
    dma2d_wdata_o  = wdata_i;
    dcmipp_wdata_o = wdata_i;

    video_wstrb_o  = wstrb_i;
    keypad_wstrb_o = wstrb_i;
    dma_wstrb_o    = wstrb_i;
    irq_wstrb_o    = wstrb_i;
    debug_wstrb_o  = wstrb_i;
    sd_wstrb_o     = wstrb_i;
    boot_wstrb_o   = wstrb_i;
    uart_wstrb_o   = wstrb_i;
    dma2d_wstrb_o  = wstrb_i;
    dcmipp_wstrb_o = wstrb_i;

    ready_o        = valid_i;
    rdata_o        = '0;

    unique case (slave_sel)
      chip8_axi_pkg::SLAVE_VIDEO: begin
        video_valid_o = valid_i;
        ready_o       = video_ready_i;
        rdata_o       = video_rdata_i;
      end
      chip8_axi_pkg::SLAVE_KEYPAD: begin
        keypad_valid_o = valid_i;
        ready_o        = keypad_ready_i;
        rdata_o        = keypad_rdata_i;
      end
      chip8_axi_pkg::SLAVE_DMA: begin
        dma_valid_o = valid_i;
        ready_o     = dma_ready_i;
        rdata_o     = dma_rdata_i;
      end
      chip8_axi_pkg::SLAVE_IRQ: begin
        irq_valid_o = valid_i;
        ready_o     = irq_ready_i;
        rdata_o     = irq_rdata_i;
      end
      chip8_axi_pkg::SLAVE_DEBUG: begin
        debug_valid_o = valid_i;
        ready_o       = debug_ready_i;
        rdata_o       = debug_rdata_i;
      end
      chip8_axi_pkg::SLAVE_SD: begin
        sd_valid_o = valid_i;
        ready_o    = sd_ready_i;
        rdata_o    = sd_rdata_i;
      end
      chip8_axi_pkg::SLAVE_BOOT: begin
        boot_valid_o = valid_i;
        ready_o      = boot_ready_i;
        rdata_o      = boot_rdata_i;
      end
      chip8_axi_pkg::SLAVE_UART: begin
        uart_valid_o = valid_i;
        ready_o      = uart_ready_i;
        rdata_o      = uart_rdata_i;
      end
      chip8_axi_pkg::SLAVE_DMA2D: begin
        dma2d_valid_o = valid_i;
        ready_o       = dma2d_ready_i;
        rdata_o       = dma2d_rdata_i;
      end
      chip8_axi_pkg::SLAVE_DCMIPP: begin
        dcmipp_valid_o = valid_i;
        ready_o        = dcmipp_ready_i;
        rdata_o        = dcmipp_rdata_i;
      end
      default: begin
        ready_o = valid_i;
        rdata_o = 32'hDEAD_0001;
      end
    endcase
  end
endmodule

`default_nettype wire

// EOF

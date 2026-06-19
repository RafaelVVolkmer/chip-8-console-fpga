// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_usb_soc_top.sv
// -----------------------------------------------------------------------------
// @brief USB SoC integration wrapper.
// =============================================================================
//
// Responsibilities:
// - Bind the SoC to the USB-oriented board IO.
// - Connect debug, storage and video paths to the board.
// - Keep platform wiring separate from reusable RTL.
//
// Characteristics:
// - Board-level integration shell.
// - Contains only glue for the chosen target board.
// - Leaves core behavior inside reusable modules.
//
// Design notes:
// - Keep board pins and clocking contracts explicit.
// =============================================================================
`default_nettype none

module chip8_usb_soc_top #(
  parameter int CLK_HZ = 27_000_000,
  parameter int VIDEO_BACKEND = chip8_axi_pkg::VIDEO_BACKEND_HDMI,
  parameter bit DEBUG_PROFILE = 1'b1,
  parameter bit ENABLE_DAP = DEBUG_PROFILE
) (
  input  logic          clk_i,
  input  logic          rst_ni,
  input  logic [3:0]    keypad_cols_i,
  input  logic [3:0]    sd_dat_i,
  input  logic          usb_uart_rx_i,
  output logic [3:0]    keypad_rows_o,
  output logic          sd_clk_o,
  output logic          sd_cmd_o,
  output logic [3:0]    sd_dat_out_o,
  output logic [3:0]    sd_dat_oe_o,
  output logic          usb_uart_tx_o,
  output logic          usb_log_valid_o,
  output logic [7:0]    usb_log_data_o,
  output logic          hdmi_clk_po,
  output logic          hdmi_clk_no,
  output logic [2:0]    hdmi_data_po,
  output logic [2:0]    hdmi_data_no,
  output logic          lcd_spi_sck_o,
  output logic          lcd_spi_mosi_o,
  output logic          lcd_spi_dc_o,
  output logic          lcd_spi_cs_o,
  output logic          lcd_spi_rst_o,
  output logic          lcd_rgb_de_o,
  output logic          lcd_rgb_hsync_o,
  output logic          lcd_rgb_vsync_o,
  output logic [5:0]    lcd_rgb_r_o,
  output logic [5:0]    lcd_rgb_g_o,
  output logic [5:0]    lcd_rgb_b_o,
  output logic [2047:0] framebuffer_o,
  output logic [11:0]   pc_o,
  output logic          sound_active_o,
  output logic          halted_o,
  output logic          irq_o,
  output logic          dap_busy_o,
  output logic          dap_error_o,
  output logic          dap_locked_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        dap_core_hold;
  logic        dap_core_release;
  logic        dap_rom_load_valid;
  logic [11:0] dap_rom_load_offset;
  logic [7:0]  dap_rom_load_data;
  logic [15:0] dap_axi_awaddr;
  logic        dap_axi_awvalid;
  logic        dap_axi_awready;
  logic [31:0] dap_axi_wdata;
  logic [3:0]  dap_axi_wstrb;
  logic        dap_axi_wvalid;
  logic        dap_axi_wready;
  logic [1:0]  dap_axi_bresp;
  logic        dap_axi_bvalid;
  logic        dap_axi_bready;
  logic [15:0] dap_axi_araddr;
  logic        dap_axi_arvalid;
  logic        dap_axi_arready;
  logic [31:0] dap_axi_rdata;
  logic [1:0]  dap_axi_rresp;
  logic        dap_axi_rvalid;
  logic        dap_axi_rready;
  logic        soc_uart_tx_unused;

  generate
    // ------------------------------------------------------------
    // Submodule instances
    // ------------------------------------------------------------

    if (ENABLE_DAP) begin : gen_debug_dap
      chip8_usb_dap_uart_bridge #(
        .CLK_HZ(CLK_HZ),
        .BAUD(115200)
      ) u_usb_dap (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .uart_rx_i(usb_uart_rx_i),
        .uart_tx_o(usb_uart_tx_o),
        .core_hold_o(dap_core_hold),
        .core_release_override_o(dap_core_release),
        .rom_load_valid_o(dap_rom_load_valid),
        .rom_load_offset_o(dap_rom_load_offset),
        .rom_load_data_o(dap_rom_load_data),
        .m_axi_awaddr_o(dap_axi_awaddr),
        .m_axi_awvalid_o(dap_axi_awvalid),
        .m_axi_awready_i(dap_axi_awready),
        .m_axi_wdata_o(dap_axi_wdata),
        .m_axi_wstrb_o(dap_axi_wstrb),
        .m_axi_wvalid_o(dap_axi_wvalid),
        .m_axi_wready_i(dap_axi_wready),
        .m_axi_bresp_i(dap_axi_bresp),
        .m_axi_bvalid_i(dap_axi_bvalid),
        .m_axi_bready_o(dap_axi_bready),
        .m_axi_araddr_o(dap_axi_araddr),
        .m_axi_arvalid_o(dap_axi_arvalid),
        .m_axi_arready_i(dap_axi_arready),
        .m_axi_rdata_i(dap_axi_rdata),
        .m_axi_rresp_i(dap_axi_rresp),
        .m_axi_rvalid_i(dap_axi_rvalid),
        .m_axi_rready_o(dap_axi_rready),
        .busy_o(dap_busy_o),
        .error_o(dap_error_o),
        .locked_o(dap_locked_o)
      );
    end else begin : gen_release_no_dap
      // ------------------------------------------------------------
      // Continuous assignments
      // ------------------------------------------------------------

      assign usb_uart_tx_o = '1;
      assign dap_busy_o = '0;
      assign dap_error_o = '0;
      assign dap_locked_o = '1;
      assign dap_core_hold = '0;
      assign dap_core_release = '0;
      assign dap_rom_load_valid = '0;
      assign dap_rom_load_offset = '0;
      assign dap_rom_load_data = '0;
      assign dap_axi_awaddr = '0;
      assign dap_axi_awvalid = '0;
      assign dap_axi_wdata = '0;
      assign dap_axi_wstrb = '0;
      assign dap_axi_wvalid = '0;
      assign dap_axi_bready = '0;
      assign dap_axi_araddr = '0;
      assign dap_axi_arvalid = '0;
      assign dap_axi_rready = '0;
    end
  endgenerate

  chip8_soc_axi #(
    .CLK_HZ(CLK_HZ),
    .VIDEO_BACKEND(VIDEO_BACKEND)
  ) u_soc (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .keypad_rows_o(keypad_rows_o),
    .keypad_cols_i(keypad_cols_i),
    .rom_load_valid_i(1'b0),
    .rom_load_offset_i(12'h000),
    .rom_load_data_i(8'h00),
    .prog_core_hold_i(dap_core_hold),
    .prog_core_release_i(dap_core_release),
    .prog_rom_load_valid_i(dap_rom_load_valid),
    .prog_rom_load_offset_i(dap_rom_load_offset),
    .prog_rom_load_data_i(dap_rom_load_data),
    .sd_clk_o(sd_clk_o),
    .sd_cmd_o(sd_cmd_o),
    .sd_dat_i(sd_dat_i),
    .sd_dat_out_o(sd_dat_out_o),
    .sd_dat_oe_o(sd_dat_oe_o),
    .usb_uart_tx_o(soc_uart_tx_unused),
    .usb_uart_rx_i(1'b1),
    .usb_log_valid_o(usb_log_valid_o),
    .usb_log_data_o(usb_log_data_o),
    .s_axi_awaddr_i(dap_axi_awaddr),
    .s_axi_awvalid_i(dap_axi_awvalid),
    .s_axi_awready_o(dap_axi_awready),
    .s_axi_wdata_i(dap_axi_wdata),
    .s_axi_wstrb_i(dap_axi_wstrb),
    .s_axi_wvalid_i(dap_axi_wvalid),
    .s_axi_wready_o(dap_axi_wready),
    .s_axi_bresp_o(dap_axi_bresp),
    .s_axi_bvalid_o(dap_axi_bvalid),
    .s_axi_bready_i(dap_axi_bready),
    .s_axi_araddr_i(dap_axi_araddr),
    .s_axi_arvalid_i(dap_axi_arvalid),
    .s_axi_arready_o(dap_axi_arready),
    .s_axi_rdata_o(dap_axi_rdata),
    .s_axi_rresp_o(dap_axi_rresp),
    .s_axi_rvalid_o(dap_axi_rvalid),
    .s_axi_rready_i(dap_axi_rready),
    .hdmi_clk_po(hdmi_clk_po),
    .hdmi_clk_no(hdmi_clk_no),
    .hdmi_data_po(hdmi_data_po),
    .hdmi_data_no(hdmi_data_no),
    .lcd_spi_sck_o(lcd_spi_sck_o),
    .lcd_spi_mosi_o(lcd_spi_mosi_o),
    .lcd_spi_dc_o(lcd_spi_dc_o),
    .lcd_spi_cs_o(lcd_spi_cs_o),
    .lcd_spi_rst_o(lcd_spi_rst_o),
    .lcd_rgb_de_o(lcd_rgb_de_o),
    .lcd_rgb_hsync_o(lcd_rgb_hsync_o),
    .lcd_rgb_vsync_o(lcd_rgb_vsync_o),
    .lcd_rgb_r_o(lcd_rgb_r_o),
    .lcd_rgb_g_o(lcd_rgb_g_o),
    .lcd_rgb_b_o(lcd_rgb_b_o),
    .framebuffer_o(framebuffer_o),
    .pc_o(pc_o),
    .sound_active_o(sound_active_o),
    .halted_o(halted_o),
    .irq_o(irq_o)
  );

  logic soc_uart_unused;
  assign soc_uart_unused = soc_uart_tx_unused;
endmodule

`default_nettype wire

// EOF

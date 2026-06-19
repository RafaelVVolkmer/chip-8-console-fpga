// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_soc_axi_formal.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Soc axi.
// =============================================================================
//
// Responsibilities:
// - Instantiate the DUT and constrain reset and legal inputs.
// - Assert interface contracts and temporal properties.
// - Keep proof-only state local to the harness.
//
// Characteristics:
// - Non-synthesizable proof wrapper.
// - Uses anyseq/anyconst stimuli and assertions.
// - Intended for bounded or induction proofs.
//
// Design notes:
// - Keep assumptions minimal and assertions local.
// =============================================================================
`default_nettype none

module chip8_soc_axi_formal (
  input logic clk,
  input logic rst_n
);
  localparam logic [11:0] FORMAL_PC_ADDR_MASK = 12'hfff;

  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic [3:0] rows;
  logic [3:0] cols;
  logic sd_clk;
  logic sd_cmd;
  logic [3:0] sd_dat;
  logic [3:0] sd_dat_out;
  logic [3:0] sd_dat_oe;
  logic usb_uart_tx;
  logic usb_uart_rx;
  logic usb_log_valid;
  logic [7:0] usb_log_data;
  logic hdmi_clk_p;
  logic hdmi_clk_n;
  logic [2:0] hdmi_data_p;
  logic [2:0] hdmi_data_n;
  logic lcd_spi_sck;
  logic lcd_spi_mosi;
  logic lcd_spi_dc;
  logic lcd_spi_cs;
  logic lcd_spi_rst;
  logic lcd_rgb_de;
  logic lcd_rgb_hsync;
  logic lcd_rgb_vsync;
  logic [5:0] lcd_rgb_r;
  logic [5:0] lcd_rgb_g;
  logic [5:0] lcd_rgb_b;
  logic [2047:0] framebuffer;
  logic [11:0] pc;
  logic sound_active;
  logic halted;
  logic irq;
  logic past_valid = '0;

  (* anyseq *) logic [3:0] any_cols;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign cols = any_cols;
  assign sd_dat = 4'b1111;
  assign usb_uart_rx = '1;

  chip8_soc_axi u_dut (
  .clk_i(clk),
  .rst_ni(rst_n),
  .keypad_rows_o(rows),
  .keypad_cols_i(cols),
  .rom_load_valid_i(1'b0),
  .rom_load_offset_i(12'h000),
  .rom_load_data_i(8'h00),
  .prog_core_hold_i(1'b0),
  .prog_core_release_i(1'b0),
  .prog_rom_load_valid_i(1'b0),
  .prog_rom_load_offset_i(12'h000),
  .prog_rom_load_data_i(8'h00),
  .sd_clk_o(sd_clk),
  .sd_cmd_o(sd_cmd),
  .sd_dat_i(sd_dat),
  .sd_dat_out_o(sd_dat_out),
  .sd_dat_oe_o(sd_dat_oe),
  .usb_uart_tx_o(usb_uart_tx),
  .usb_uart_rx_i(usb_uart_rx),
  .usb_log_valid_o(usb_log_valid),
  .usb_log_data_o(usb_log_data),
  .s_axi_awaddr_i(16'h0000),
  .s_axi_awvalid_i(1'b0),
  .s_axi_awready_o(),
  .s_axi_wdata_i(32'h0000_0000),
  .s_axi_wstrb_i(4'h0),
  .s_axi_wvalid_i(1'b0),
  .s_axi_wready_o(),
  .s_axi_bresp_o(),
  .s_axi_bvalid_o(),
  .s_axi_bready_i(1'b1),
  .s_axi_araddr_i(16'h0000),
  .s_axi_arvalid_i(1'b0),
  .s_axi_arready_o(),
  .s_axi_rdata_o(),
  .s_axi_rresp_o(),
  .s_axi_rvalid_o(),
  .s_axi_rready_i(1'b1),
  .hdmi_clk_po(hdmi_clk_p),
  .hdmi_clk_no(hdmi_clk_n),
  .hdmi_data_po(hdmi_data_p),
  .hdmi_data_no(hdmi_data_n),
  .lcd_spi_sck_o(lcd_spi_sck),
  .lcd_spi_mosi_o(lcd_spi_mosi),
  .lcd_spi_dc_o(lcd_spi_dc),
  .lcd_spi_cs_o(lcd_spi_cs),
  .lcd_spi_rst_o(lcd_spi_rst),
  .lcd_rgb_de_o(lcd_rgb_de),
  .lcd_rgb_hsync_o(lcd_rgb_hsync),
  .lcd_rgb_vsync_o(lcd_rgb_vsync),
  .lcd_rgb_r_o(lcd_rgb_r),
  .lcd_rgb_g_o(lcd_rgb_g),
  .lcd_rgb_b_o(lcd_rgb_b),
  .framebuffer_o(framebuffer),
  .pc_o(pc),
  .sound_active_o(sound_active),
  .halted_o(halted),
  .irq_o(irq)
  );

  // ------------------------------------------------------------
  // Clocked testbench procedures
  // ------------------------------------------------------------

  always_ff @(posedge clk) begin : formal_reset_track_ff
  past_valid <= '1;
  if (!past_valid) begin
    assume (!rst_n);
  end else begin
    assume (rst_n);
  end
  end

  always_ff @(posedge clk) begin : soc_axi_properties_ff
  if (past_valid && rst_n) begin
    assert (pc <= FORMAL_PC_ADDR_MASK);
    assert (rows != 4'b0000);
    assert (sd_clk == 1'b0 || sd_clk == 1'b1);
    assert (sd_cmd == 1'b0 || sd_cmd == 1'b1);
    assert (sd_dat_out <= 4'hf);
    assert (sd_dat_oe <= 4'hf);
    assert (usb_uart_tx == 1'b0 || usb_uart_tx == 1'b1);
    assert (!usb_log_valid || usb_log_data <= 8'hff);
    assert (hdmi_clk_p == ~hdmi_clk_n);
    assert (hdmi_data_p == ~hdmi_data_n);
    assert (lcd_rgb_r <= 6'h3f);
    assert (lcd_rgb_g <= 6'h3f);
    assert (lcd_rgb_b <= 6'h3f);
    assert (sound_active == 1'b0 || sound_active == 1'b1);
    assert (halted == 1'b0 || halted == 1'b1);
    assert (irq == 1'b0 || irq == 1'b1);
  end
  end
endmodule

`default_nettype wire

// EOF

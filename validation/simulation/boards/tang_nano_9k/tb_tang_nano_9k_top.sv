// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tb_tang_nano_9k_top.sv
// -----------------------------------------------------------------------------
// @brief Board integration wrapper for Tang Nano 9K board.
// =============================================================================
//
// Responsibilities:
// - Bind board clocks, resets and IO to the reusable SoC.
// - Instantiate the platform-specific top-level glue.
// - Keep board-only policy out of the core RTL.
//
// Characteristics:
// - Top-level integration only.
// - Contains no architectural CPU state.
// - Separates board glue from reusable blocks.
//
// Design notes:
// - Keep the board pin contract obvious.
// =============================================================================
`default_nettype none

module tb_tang_nano_9k_top;
  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic clk;
  logic rst_n;
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
  logic sound;
  logic irq;
  logic [5:0] led;

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  initial clk = '0;
  always #5 clk = ~clk;

  tang_nano_9k_top u_top (
  .clk_27mhz_i(clk),
  .reset_button_ni(rst_n),
  .keypad_rows_o(rows),
  .keypad_cols_i(cols),
  .sd_clk_o(sd_clk),
  .sd_cmd_o(sd_cmd),
  .sd_dat_i(sd_dat),
  .sd_dat_out_o(sd_dat_out),
  .sd_dat_oe_o(sd_dat_oe),
  .usb_uart_tx_o(usb_uart_tx),
  .usb_uart_rx_i(usb_uart_rx),
  .usb_log_valid_o(usb_log_valid),
  .usb_log_data_o(usb_log_data),
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
  .sound_o(sound),
  .irq_o(irq),
  .led_o(led)
  );

  // ------------------------------------------------------------
  // Testbench tasks
  // ------------------------------------------------------------

  task automatic tick;
  @(posedge clk);
  #1;
  endtask

  initial begin : board_top_smoke
  rst_n = '0;
  cols = 4'b1111;
  sd_dat = 4'b1111;
  usb_uart_rx = '1;
  repeat (5) tick();
  rst_n = '1;
  repeat (50) begin
    tick();
    assert (rows != 4'bxxxx);
    assert (sd_dat_oe != 4'bxxxx);
    assert (sd_clk === 1'b0 || sd_clk === 1'b1);
    assert (sd_cmd === 1'b0 || sd_cmd === 1'b1);
    assert (usb_uart_tx === 1'b0 || usb_uart_tx === 1'b1);
    assert (hdmi_clk_p == ~hdmi_clk_n);
    assert (hdmi_data_p == ~hdmi_data_n);
  end
  assert (!usb_log_valid || !$isunknown(usb_log_data));
  assert (sd_dat_out != 4'bxxxx);
  if ($isunknown(led)) begin
    $display(
    "led=%b irq=%b halt=%b snd=%b hb=%b pc=%03h",
    led,
    u_top.irq_o,
    u_top.halted,
    u_top.sound_active,
    u_top.heartbeat_q[23],
    u_top.pc
    );
  end
  assert (!$isunknown(led));
  assert (!irq || irq);
  assert (!sound || sound);
  $finish;
  end
endmodule

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tb_chip8_boot_pipeline.sv
// -----------------------------------------------------------------------------
// @brief SoC integration wrapper for Tb chip8 boot pipeline.
// =============================================================================
//
// Responsibilities:
// - Compose the CPU, memory, video, storage and debug blocks.
// - Route clocks, resets, buses and interrupts explicitly.
// - Keep integration policy outside leaf modules.
//
// Characteristics:
// - Top-level composition block.
// - Owns interconnect, not leaf algorithms.
// - Bridges board pins to reusable modules.
//
// Design notes:
// - Keep subsystem windows and clock domains named.
// =============================================================================
`default_nettype none

module tb_chip8_boot_pipeline;
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam int CLK_HZ = 1_000_000;

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
  logic sd_dat0_q;
  logic usb_uart_tx;
  logic usb_uart_rx;
  logic usb_log_valid;
  logic [7:0] usb_log_data;
  logic [15:0] awaddr;
  logic awvalid;
  logic awready;
  logic [31:0] wdata;
  logic [3:0] wstrb;
  logic wvalid;
  logic wready;
  logic [1:0] bresp;
  logic bvalid;
  logic [15:0] araddr;
  logic arvalid;
  logic arready;
  logic [31:0] rdata;
  logic [1:0] rresp;
  logic rvalid;
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
  logic [7:0] sd_rom [0:511];
  int sd_bit_count;
  int usb_log_count;
  int lit_pixels;
  logic [31:0] dcmipp_frames_before;
  logic [31:0] dcmipp_frames_after;
  logic [31:0] dcmipp_hash_before;
  logic [31:0] dcmipp_hash_after;
  logic [31:0] read_tmp;
  logic [31:0] boot_status;
  logic [31:0] debug_status;
  logic [31:0] scb_hfsr;
  logic [31:0] scb_cfsr;
  logic [31:0] scb_mmfar;
  logic [31:0] scb_bfar;
  logic [31:0] scb_shcsr;
  logic [31:0] scb_dfsr;
  logic [31:0] scb_afsr;
  logic [31:0] sd_status;
  logic [31:0] sd_count;
  logic [31:0] sd_timeout;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign sd_dat = {3'b111, sd_dat0_q};

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  initial clk = '0;
  always #5 clk = ~clk;

  chip8_soc_axi #(
  .CLK_HZ(CLK_HZ),
  .VIDEO_BACKEND(chip8_axi_pkg::VIDEO_BACKEND_HDMI),
  .SD_SIM_BOOT_ROM(1'b1)
  ) u_dut (
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
  .s_axi_awaddr_i(awaddr),
  .s_axi_awvalid_i(awvalid),
  .s_axi_awready_o(awready),
  .s_axi_wdata_i(wdata),
  .s_axi_wstrb_i(wstrb),
  .s_axi_wvalid_i(wvalid),
  .s_axi_wready_o(wready),
  .s_axi_bresp_o(bresp),
  .s_axi_bvalid_o(bvalid),
  .s_axi_bready_i(1'b1),
  .s_axi_araddr_i(araddr),
  .s_axi_arvalid_i(arvalid),
  .s_axi_arready_o(arready),
  .s_axi_rdata_o(rdata),
  .s_axi_rresp_o(rresp),
  .s_axi_rvalid_o(rvalid),
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
  // Combinational checks
  // ------------------------------------------------------------

  always_comb begin : keypad_mock_comb
  cols = 4'b1111;
  if (!rows[1]) begin
    cols[2] = '0;
  end
  end

  // ------------------------------------------------------------
  // Testbench tasks
  // ------------------------------------------------------------

  function automatic logic [7:0] sd_payload_byte(input int byte_idx);
    if (byte_idx == 0) begin
      sd_payload_byte = 8'hfe;
    end else if (byte_idx >= 1 && byte_idx <= 512) begin
      sd_payload_byte = sd_rom[byte_idx - 1];
    end else begin
      sd_payload_byte = 8'hff;
    end
  endfunction

  function automatic logic sd_payload_bit(input int bit_count);
    int payload_bit;
    int byte_idx;
    int bit_idx;
    logic [7:0] payload_byte;

    payload_bit = bit_count - 64;
    byte_idx = payload_bit / 8;
    bit_idx = 7 - (payload_bit % 8);
    payload_byte = sd_payload_byte(byte_idx);
    sd_payload_bit = payload_byte[bit_idx];
  endfunction

  always_ff @(negedge sd_clk or negedge rst_n) begin : sd_card_mock_shift
    if (!rst_n || !(sd_dat_oe[3] && !sd_dat_out[3])) begin
      sd_bit_count <= '0;
      sd_dat0_q <= '1;
    end else begin
      if (sd_bit_count < 64) begin
        sd_dat0_q <= '1;
      end else begin
        sd_dat0_q <= sd_payload_bit(sd_bit_count);
      end
      sd_bit_count <= sd_bit_count + 1;
    end
  end

  // ------------------------------------------------------------
  // Clocked testbench procedures
  // ------------------------------------------------------------

  always_ff @(posedge clk) begin : usb_log_counter_ff
  if (!rst_n) begin
    usb_log_count <= '0;
  end else if (usb_log_valid) begin
    usb_log_count <= usb_log_count + 1;
    assert (usb_log_data != 8'h00) else $fatal(1,
    "USB log emitted NUL byte");
  end
  end

  task automatic axi_write(input logic [15:0] addr, input logic [31:0] data);
  begin
    awaddr  <= addr;
    wdata   <= data;
    wstrb   <= 4'hf;
    awvalid <= '1;
    wvalid  <= '1;
    do @(posedge clk); while (!awready || !wready);
    awvalid <= '0;
    wvalid  <= '0;
    do @(posedge clk); while (!bvalid);
    assert (bresp == 2'b00) else $fatal(1, "AXI write response error");
    @(posedge clk);
  end
  endtask

  task automatic axi_read(input logic [15:0] addr, output logic [31:0] data);
  begin
    araddr  <= addr;
    arvalid <= '1;
    do @(posedge clk); while (!arready);
    arvalid <= '0;
    do @(posedge clk); while (!rvalid);
    data = rdata;
    assert (rresp == 2'b00) else $fatal(1, "AXI read response error");
    @(posedge clk);
  end
  endtask

  task automatic wait_cycles(input int cycles);
  for (int idx = '0; idx < cycles; idx++) begin
    @(posedge clk);
  end
  endtask

  initial begin : init_rom
  for (int idx = '0; idx < 512; idx++) begin
    sd_rom[idx] = '0;
  end
  sd_rom[0]  = '0;
  sd_rom[1]  = 8'he0;
  sd_rom[2]  = 8'h60;
  sd_rom[3]  = 8'h08;
  sd_rom[4]  = 8'h61;
  sd_rom[5]  = 8'h08;
  sd_rom[6]  = 8'ha0;
  sd_rom[7]  = '0;
  sd_rom[8]  = 8'hd0;
  sd_rom[9]  = 8'h15;
  sd_rom[10] = 8'h70;
  sd_rom[11] = 8'h08;
  sd_rom[12] = 8'h62;
  sd_rom[13] = 8'h0a;
  sd_rom[14] = 8'h80;
  sd_rom[15] = 8'h24;
  sd_rom[16] = 8'ha0;
  sd_rom[17] = 8'h05;
  sd_rom[18] = 8'hd0;
  sd_rom[19] = 8'h15;
  sd_rom[20] = 8'h12;
  sd_rom[21] = 8'h14;
  end

  initial begin : boot_pipeline_e2e
  rst_n = '0;
  usb_uart_rx = '1;
  awaddr = '0;
  awvalid = '0;
  wdata = '0;
  wstrb = '0;
  wvalid = '0;
  araddr = '0;
  arvalid = '0;
  wait_cycles(8);
  rst_n = '1;

  boot_status = '0;
  for (int poll = '0; poll < 128 && !boot_status[3]; poll++) begin
    wait_cycles(128);
    axi_read(16'h1604, boot_status);
  end
  axi_read(16'h1504, sd_status);
  axi_read(16'h1510, sd_count);
  axi_read(16'h1514, sd_timeout);
  axi_read(16'h1400, debug_status);
  axi_read(16'h1424, scb_shcsr);
  axi_read(16'h1428, scb_cfsr);
  axi_read(16'h142c, scb_hfsr);
  axi_read(16'h1430, scb_dfsr);
  axi_read(16'h1434, scb_mmfar);
  axi_read(16'h1438, scb_bfar);
  axi_read(16'h143c, scb_afsr);
  $display(
    "boot: pc=%03h boot=%08h sd=%08h count=%08h",
    pc,
    boot_status,
    sd_status,
    sd_count
  );
  $display(
    "boot: timeout=%08h debug=%08h usb_logs=%0d",
    sd_timeout,
    debug_status,
    usb_log_count
  );

  assert (boot_status[3]) else $fatal(1,
    "bootloader did not release core");
  assert (scb_shcsr == 32'h0004_0000) else $fatal(1,
    "unexpected SHCSR: %08h", scb_shcsr);
  assert (scb_cfsr == 32'h0000_0000) else $fatal(1,
    "unexpected CFSR: %08h", scb_cfsr);
  assert (scb_hfsr == 32'h0000_0000) else $fatal(1,
    "unexpected HFSR: %08h", scb_hfsr);
  assert (scb_dfsr == 32'h0000_0000) else $fatal(1,
    "unexpected DFSR: %08h", scb_dfsr);
  assert (scb_mmfar == 32'h0000_0000) else $fatal(1,
    "unexpected MMFAR: %08h", scb_mmfar);
  assert (scb_bfar == 32'h0000_0000) else $fatal(1,
    "unexpected BFAR: %08h", scb_bfar);
  assert (scb_afsr == 32'h0000_0000) else $fatal(1,
    "unexpected AFSR: %08h", scb_afsr);
  wait_cycles(800);
  assert (!halted) else $fatal(1, "core halted after SD boot");
  assert (pc == 12'h214 || pc == 12'h216 || pc == 12'h218) else $fatal(1,
    "unexpected booted PC: %03h", pc);

  lit_pixels = '0;
  for (int idx = '0; idx < 2048; idx++) begin
    lit_pixels += int'(framebuffer[idx]);
  end
  assert (lit_pixels >= 22) else $fatal(1,
    "booted ROM did not draw expected pixels: %0d", lit_pixels);

  axi_read(16'h1908, dcmipp_frames_before);
  axi_read(16'h1910, dcmipp_hash_before);
  axi_write(16'h1900, 32'h0000_0007);
  wait_cycles(2500);
  axi_read(16'h1908, dcmipp_frames_after);
  axi_read(16'h1910, dcmipp_hash_after);
  assert (dcmipp_frames_after > dcmipp_frames_before) else $fatal(1,
    "DCMIPP frame counter did not advance");
  assert (dcmipp_hash_after != dcmipp_hash_before) else $fatal(1,
    "DCMIPP hash did not change after controls");

  axi_write(16'h1808, 32'h0000_0001);
  axi_write(16'h180c, 32'h0000_0000);
  axi_write(16'h1810, 32'h0000_2040);
  axi_write(16'h1800, 32'h0000_0005);
  wait_cycles(2500);
  axi_read(16'h1804, read_tmp);
  assert (!read_tmp[3]) else $fatal(1, "DMA2D reported error");

  assert (hdmi_clk_p == ~hdmi_clk_n) else $fatal(1,
    "HDMI clock pair mismatch");
  assert (hdmi_data_p == ~hdmi_data_n) else $fatal(1,
    "HDMI data pair mismatch");
  assert (usb_uart_tx === 1'b0 || usb_uart_tx === 1'b1) else $fatal(1,
    "USB UART TX unknown");
  assert (sound_active === 1'b0 || sound_active === 1'b1) else $fatal(1,
    "sound unknown");

  $display(
    "boot done: pc=%03h usb_logs=%0d frames=%0d hash=%08h",
    pc,
    usb_log_count,
    dcmipp_frames_after,
    dcmipp_hash_after
  );
  $finish;
  end
endmodule

`default_nettype wire

// EOF

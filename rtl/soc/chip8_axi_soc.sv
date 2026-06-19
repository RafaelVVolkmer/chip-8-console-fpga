// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_axi_soc.sv
// -----------------------------------------------------------------------------
// @brief SoC integration wrapper.
// =============================================================================
//
// Responsibilities:
// - Compose the CPU, memory, video, storage and debug subsystems.
// - Route AXI and register-side transactions to the right block.
// - Keep system clocking, reset and interrupt wiring visible.
//
// Characteristics:
// - Top-level SoC composition block.
// - Owns interconnect, not individual algorithms.
// - Bridges board pins to reusable leaf modules.
//
// Design notes:
// - Keep peripheral windows and debug paths named.
// =============================================================================
`default_nettype none

module chip8_soc_axi #(
  parameter int CLK_HZ = 27_000_000,
  parameter int VIDEO_BACKEND = chip8_axi_pkg::VIDEO_BACKEND_HDMI,
  parameter bit SD_SIM_BOOT_ROM = 1'b0
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  output logic [3:0]  keypad_rows_o,
  input  logic [3:0]  keypad_cols_i,

  input  logic        rom_load_valid_i,
  input  logic [11:0] rom_load_offset_i,
  input  logic [7:0]  rom_load_data_i,

  input  logic        prog_core_hold_i,
  input  logic        prog_core_release_i,
  input  logic        prog_rom_load_valid_i,
  input  logic [11:0] prog_rom_load_offset_i,
  input  logic [7:0]  prog_rom_load_data_i,

  output logic        sd_clk_o,
  output logic        sd_cmd_o,
  input  logic [3:0]  sd_dat_i,
  output logic [3:0]  sd_dat_out_o,
  output logic [3:0]  sd_dat_oe_o,

  output logic        usb_uart_tx_o,
  input  logic        usb_uart_rx_i,
  output logic        usb_log_valid_o,
  output logic [7:0]  usb_log_data_o,

  input  logic [15:0] s_axi_awaddr_i,
  input  logic        s_axi_awvalid_i,
  output logic        s_axi_awready_o,
  input  logic [31:0] s_axi_wdata_i,
  input  logic [3:0]  s_axi_wstrb_i,
  input  logic        s_axi_wvalid_i,
  output logic        s_axi_wready_o,
  output logic [1:0]  s_axi_bresp_o,
  output logic        s_axi_bvalid_o,
  input  logic        s_axi_bready_i,
  input  logic [15:0] s_axi_araddr_i,
  input  logic        s_axi_arvalid_i,
  output logic        s_axi_arready_o,
  output logic [31:0] s_axi_rdata_o,
  output logic [1:0]  s_axi_rresp_o,
  output logic        s_axi_rvalid_o,
  input  logic        s_axi_rready_i,

  output logic        hdmi_clk_po,
  output logic        hdmi_clk_no,
  output logic [2:0]  hdmi_data_po,
  output logic [2:0]  hdmi_data_no,

  output logic        lcd_spi_sck_o,
  output logic        lcd_spi_mosi_o,
  output logic        lcd_spi_dc_o,
  output logic        lcd_spi_cs_o,
  output logic        lcd_spi_rst_o,

  output logic        lcd_rgb_de_o,
  output logic        lcd_rgb_hsync_o,
  output logic        lcd_rgb_vsync_o,
  output logic [5:0]  lcd_rgb_r_o,
  output logic [5:0]  lcd_rgb_g_o,
  output logic [5:0]  lcd_rgb_b_o,

  output logic [2047:0] framebuffer_o,
  output logic [11:0] pc_o,
  output logic        sound_active_o,
  output logic        halted_o,
  output logic        irq_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [7:0] DEBUG_STATUS_OFFSET = 8'h00;
  localparam logic [7:0] DEBUG_CORE_STATUS_OFFSET = 8'h04;
  localparam logic [7:0] DEBUG_SCB_SHCSR_OFFSET = 8'h24;
  localparam logic [7:0] DEBUG_SCB_CFSR_OFFSET = 8'h28;
  localparam logic [7:0] DEBUG_SCB_HFSR_OFFSET = 8'h2c;
  localparam logic [7:0] DEBUG_SCB_DFSR_OFFSET = 8'h30;
  localparam logic [7:0] DEBUG_SCB_MMFAR_OFFSET = 8'h34;
  localparam logic [7:0] DEBUG_SCB_BFAR_OFFSET = 8'h38;
  localparam logic [7:0] DEBUG_SCB_AFSR_OFFSET = 8'h3c;
  localparam logic [7:0] CHIP8_AXI_IDLE_CAMERA_SAMPLE = '0;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        reg_valid;
  logic        reg_we;
  logic [15:0] reg_addr;
  logic [31:0] reg_wdata;
  logic [3:0]  reg_wstrb;
  logic        reg_ready;
  logic [31:0] reg_rdata;

  logic        video_valid;
  logic        video_we;
  logic [7:0]  video_addr;
  logic [31:0] video_wdata;
  logic [3:0]  video_wstrb;
  logic        video_ready;
  logic [31:0] video_rdata;

  logic        keypad_valid;
  logic        keypad_we;
  logic [7:0]  keypad_addr;
  logic [31:0] keypad_wdata;
  logic [3:0]  keypad_wstrb;
  logic        keypad_ready;
  logic [31:0] keypad_rdata;

  logic        dma_valid;
  logic        dma_we;
  logic [7:0]  dma_addr;
  logic [31:0] dma_wdata;
  logic [3:0]  dma_wstrb;
  logic        dma_ready;
  logic [31:0] dma_rdata;

  logic        irq_valid;
  logic        irq_we;
  logic [7:0]  irq_addr;
  logic [31:0] irq_wdata;
  logic [3:0]  irq_wstrb;
  logic        irq_ready;
  logic [31:0] irq_rdata;

  logic        debug_valid;
  logic [7:0]  debug_addr;
  logic        debug_ready;
  logic [31:0] debug_rdata;

  logic        sd_valid;
  logic        sd_we;
  logic [7:0]  sd_addr;
  logic [31:0] sd_wdata;
  logic [3:0]  sd_wstrb;
  logic        sd_ready;
  logic [31:0] sd_rdata;

  logic        boot_valid;
  logic        boot_we;
  logic [7:0]  boot_addr;
  logic [31:0] boot_wdata;
  logic [3:0]  boot_wstrb;
  logic        boot_ready;
  logic [31:0] boot_rdata;

  logic        uart_valid;
  logic        uart_we;
  logic [7:0]  uart_addr;
  logic [31:0] uart_wdata;
  logic [3:0]  uart_wstrb;
  logic        uart_ready;
  logic [31:0] uart_rdata;

  logic        dma2d_valid;
  logic        dma2d_we;
  logic [7:0]  dma2d_addr;
  logic [31:0] dma2d_wdata;
  logic [3:0]  dma2d_wstrb;
  logic        dma2d_ready;
  logic [31:0] dma2d_rdata;

  logic        dcmipp_valid;
  logic        dcmipp_we;
  logic [7:0]  dcmipp_addr;
  logic [31:0] dcmipp_wdata;
  logic [3:0]  dcmipp_wstrb;
  logic        dcmipp_ready;
  logic [31:0] dcmipp_rdata;

  logic [15:0] key_bitmap;
  logic        key_valid;
  logic [3:0]  key_code;
  logic        irq_key_event;
  logic        irq_key_overflow;
  logic        key_dma_done;

  logic        irq_video_done;
  logic        irq_video_vblank;
  logic        irq_video_error;
  logic        video_dma_done;
  logic        dma_error_irq;
  logic [15:0] irq_sources;
  logic        irq_sd_done;
  logic        irq_sd_error;
  logic        irq_boot_done;
  logic        irq_boot_error;
  logic        irq_uart_rx;
  logic        irq_dma2d_done;
  logic        irq_dma2d_error;
  logic        irq_dcmipp_frame;

  logic [2047:0] core_framebuffer;
  logic [31:0] core_debug_status;
  logic [31:0] core_scb_hfsr;
  logic [31:0] core_scb_cfsr;
  logic [31:0] core_scb_mmfar;
  logic [31:0] core_scb_bfar;
  logic [31:0] core_scb_shcsr;
  logic [31:0] core_scb_dfsr;
  logic [31:0] core_scb_afsr;
  logic [10:0] core_fb_scan_addr;
  logic        core_fb_scan_pixel;
  logic [2047:0] dma2d_framebuffer;
  logic [2047:0] dcmipp_framebuffer;
  logic          dcmipp_pixel_valid;
  logic [5:0]    dcmipp_pixel_x;
  logic [4:0]    dcmipp_pixel_y;

  logic        core_rst_n;
  logic        boot_core_rst_n;
  logic        sd_boot_start;
  logic [31:0] sd_boot_lba;
  logic [15:0] sd_boot_length;
  logic        sd_boot_busy;
  logic        sd_boot_done;
  logic        sd_boot_error;
  logic        sd_stream_valid;
  logic [7:0]  sd_stream_data;
  logic [15:0] sd_stream_offset;
  logic        boot_rom_load_valid;
  logic [11:0] boot_rom_load_offset;
  logic [7:0]  boot_rom_load_data;
  logic        boot_log_valid;
  logic [7:0]  boot_log_data;
  logic        boot_log_ready;
  logic        core_rom_load_ready;
  logic        arb_rom_load_valid;
  logic [11:0] arb_rom_load_offset;
  logic [7:0]  arb_rom_load_data;

  logic        boot_rom_load_ready;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign core_fb_scan_addr = '0;

  chip8_axi_lite_to_reg u_axi_frontend (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .s_axi_awaddr_i(s_axi_awaddr_i),
    .s_axi_awvalid_i(s_axi_awvalid_i),
    .s_axi_awready_o(s_axi_awready_o),
    .s_axi_wdata_i(s_axi_wdata_i),
    .s_axi_wstrb_i(s_axi_wstrb_i),
    .s_axi_wvalid_i(s_axi_wvalid_i),
    .s_axi_wready_o(s_axi_wready_o),
    .s_axi_bresp_o(s_axi_bresp_o),
    .s_axi_bvalid_o(s_axi_bvalid_o),
    .s_axi_bready_i(s_axi_bready_i),
    .s_axi_araddr_i(s_axi_araddr_i),
    .s_axi_arvalid_i(s_axi_arvalid_i),
    .s_axi_arready_o(s_axi_arready_o),
    .s_axi_rdata_o(s_axi_rdata_o),
    .s_axi_rresp_o(s_axi_rresp_o),
    .s_axi_rvalid_o(s_axi_rvalid_o),
    .s_axi_rready_i(s_axi_rready_i),
    .reg_valid_o(reg_valid),
    .reg_we_o(reg_we),
    .reg_addr_o(reg_addr),
    .reg_wdata_o(reg_wdata),
    .reg_wstrb_o(reg_wstrb),
    .reg_ready_i(reg_ready),
    .reg_rdata_i(reg_rdata)
  );

  chip8_reg_interconnect u_reg_xbar (
    .valid_i(reg_valid),
    .we_i(reg_we),
    .addr_i(reg_addr),
    .wdata_i(reg_wdata),
    .wstrb_i(reg_wstrb),
    .ready_o(reg_ready),
    .rdata_o(reg_rdata),
    .video_valid_o(video_valid),
    .video_we_o(video_we),
    .video_addr_o(video_addr),
    .video_wdata_o(video_wdata),
    .video_wstrb_o(video_wstrb),
    .video_ready_i(video_ready),
    .video_rdata_i(video_rdata),
    .keypad_valid_o(keypad_valid),
    .keypad_we_o(keypad_we),
    .keypad_addr_o(keypad_addr),
    .keypad_wdata_o(keypad_wdata),
    .keypad_wstrb_o(keypad_wstrb),
    .keypad_ready_i(keypad_ready),
    .keypad_rdata_i(keypad_rdata),
    .dma_valid_o(dma_valid),
    .dma_we_o(dma_we),
    .dma_addr_o(dma_addr),
    .dma_wdata_o(dma_wdata),
    .dma_wstrb_o(dma_wstrb),
    .dma_ready_i(dma_ready),
    .dma_rdata_i(dma_rdata),
    .irq_valid_o(irq_valid),
    .irq_we_o(irq_we),
    .irq_addr_o(irq_addr),
    .irq_wdata_o(irq_wdata),
    .irq_wstrb_o(irq_wstrb),
    .irq_ready_i(irq_ready),
    .irq_rdata_i(irq_rdata),
    .debug_valid_o(debug_valid),
    .debug_we_o(),
    .debug_addr_o(debug_addr),
    .debug_wdata_o(),
    .debug_wstrb_o(),
    .debug_ready_i(debug_ready),
    .debug_rdata_i(debug_rdata),
    .sd_valid_o(sd_valid),
    .sd_we_o(sd_we),
    .sd_addr_o(sd_addr),
    .sd_wdata_o(sd_wdata),
    .sd_wstrb_o(sd_wstrb),
    .sd_ready_i(sd_ready),
    .sd_rdata_i(sd_rdata),
    .boot_valid_o(boot_valid),
    .boot_we_o(boot_we),
    .boot_addr_o(boot_addr),
    .boot_wdata_o(boot_wdata),
    .boot_wstrb_o(boot_wstrb),
    .boot_ready_i(boot_ready),
    .boot_rdata_i(boot_rdata),
    .uart_valid_o(uart_valid),
    .uart_we_o(uart_we),
    .uart_addr_o(uart_addr),
    .uart_wdata_o(uart_wdata),
    .uart_wstrb_o(uart_wstrb),
    .uart_ready_i(uart_ready),
    .uart_rdata_i(uart_rdata),
    .dma2d_valid_o(dma2d_valid),
    .dma2d_we_o(dma2d_we),
    .dma2d_addr_o(dma2d_addr),
    .dma2d_wdata_o(dma2d_wdata),
    .dma2d_wstrb_o(dma2d_wstrb),
    .dma2d_ready_i(dma2d_ready),
    .dma2d_rdata_i(dma2d_rdata),
    .dcmipp_valid_o(dcmipp_valid),
    .dcmipp_we_o(dcmipp_we),
    .dcmipp_addr_o(dcmipp_addr),
    .dcmipp_wdata_o(dcmipp_wdata),
    .dcmipp_wstrb_o(dcmipp_wstrb),
    .dcmipp_ready_i(dcmipp_ready),
    .dcmipp_rdata_i(dcmipp_rdata)
  );

  chip8_sd_spi_host #(
    .SIM_BOOT_ROM(SD_SIM_BOOT_ROM)
  ) u_sd_host (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .sd_clk_o(sd_clk_o),
    .sd_cmd_o(sd_cmd_o),
    .sd_dat_i(sd_dat_i),
    .sd_dat_out_o(sd_dat_out_o),
    .sd_dat_oe_o(sd_dat_oe_o),
    .boot_read_start_i(sd_boot_start),
    .boot_lba_i(sd_boot_lba),
    .boot_length_i(sd_boot_length),
    .boot_busy_o(sd_boot_busy),
    .boot_done_o(sd_boot_done),
    .boot_error_o(sd_boot_error),
    .stream_valid_o(sd_stream_valid),
    .stream_data_o(sd_stream_data),
    .stream_offset_o(sd_stream_offset),
    .reg_valid_i(sd_valid),
    .reg_we_i(sd_we),
    .reg_addr_i(sd_addr),
    .reg_wdata_i(sd_wdata),
    .reg_wstrb_i(sd_wstrb),
    .reg_ready_o(sd_ready),
    .reg_rdata_o(sd_rdata)
  );

  chip8_bootloader u_bootloader (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .core_rst_no(boot_core_rst_n),
    .sd_read_start_o(sd_boot_start),
    .sd_lba_o(sd_boot_lba),
    .sd_length_o(sd_boot_length),
    .sd_busy_i(sd_boot_busy),
    .sd_done_i(sd_boot_done),
    .sd_error_i(sd_boot_error),
    .sd_stream_valid_i(sd_stream_valid),
    .sd_stream_data_i(sd_stream_data),
    .sd_stream_offset_i(sd_stream_offset),
    .rom_load_valid_o(boot_rom_load_valid),
    .rom_load_ready_i(boot_rom_load_ready),
    .rom_load_offset_o(boot_rom_load_offset),
    .rom_load_data_o(boot_rom_load_data),
    .log_valid_o(boot_log_valid),
    .log_data_o(boot_log_data),
    .log_ready_i(boot_log_ready),
    .irq_done_o(irq_boot_done),
    .irq_error_o(irq_boot_error),
    .reg_valid_i(boot_valid),
    .reg_we_i(boot_we),
    .reg_addr_i(boot_addr),
    .reg_wdata_i(boot_wdata),
    .reg_wstrb_i(boot_wstrb),
    .reg_ready_o(boot_ready),
    .reg_rdata_o(boot_rdata)
  );

  assign core_rst_n = (boot_core_rst_n || prog_core_release_i) &&
    !prog_core_hold_i;

  chip8_rom_load_arbiter u_rom_load_arbiter (
    .boot_valid_i(boot_rom_load_valid),
    .boot_ready_o(boot_rom_load_ready),
    .boot_offset_i(boot_rom_load_offset),
    .boot_data_i(boot_rom_load_data),
    .prog_valid_i(prog_rom_load_valid_i),
    .prog_ready_o(),
    .prog_offset_i(prog_rom_load_offset_i),
    .prog_data_i(prog_rom_load_data_i),
    .ext_valid_i(rom_load_valid_i),
    .ext_ready_o(),
    .ext_offset_i(rom_load_offset_i),
    .ext_data_i(rom_load_data_i),
    .rom_valid_o(arb_rom_load_valid),
    .rom_ready_i(core_rom_load_ready),
    .rom_offset_o(arb_rom_load_offset),
    .rom_data_o(arb_rom_load_data)
  );

  chip8_uart_debug #(
    .CLK_HZ(CLK_HZ)
  ) u_uart_debug (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .uart_tx_o(usb_uart_tx_o),
    .uart_rx_i(usb_uart_rx_i),
    .log_valid_i(boot_log_valid),
    .log_data_i(boot_log_data),
    .log_ready_o(boot_log_ready),
    .usb_artifact_valid_o(usb_log_valid_o),
    .usb_artifact_data_o(usb_log_data_o),
    .irq_rx_o(irq_uart_rx),
    .reg_valid_i(uart_valid),
    .reg_we_i(uart_we),
    .reg_addr_i(uart_addr),
    .reg_wdata_i(uart_wdata),
    .reg_wstrb_i(uart_wstrb),
    .reg_ready_o(uart_ready),
    .reg_rdata_o(uart_rdata)
  );

  chip8_keypad_accel #(
    .CLK_HZ(CLK_HZ)
  ) u_keypad_remote (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .rows_o(keypad_rows_o),
    .cols_i(keypad_cols_i),
    .key_bitmap_o(key_bitmap),
    .key_valid_o(key_valid),
    .key_code_o(key_code),
    .irq_event_o(irq_key_event),
    .irq_overflow_o(irq_key_overflow),
    .dma_done_o(key_dma_done),
    .reg_valid_i(keypad_valid),
    .reg_we_i(keypad_we),
    .reg_addr_i(keypad_addr),
    .reg_wdata_i(keypad_wdata),
    .reg_wstrb_i(keypad_wstrb),
    .reg_ready_o(keypad_ready),
    .reg_rdata_o(keypad_rdata)
  );

  chip8_soc #(
    .CLK_HZ(CLK_HZ),
    .TICK_HZ(chip8_config_pkg::CHIP8_TIMER_HZ),
    .TRAP_ILLEGAL(1'b0)
  ) u_chip8_nominal_soc (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .cpu_enable_i(core_rst_n),
    .keys_i(key_bitmap),
    .rom_load_valid_i(arb_rom_load_valid),
    .rom_load_ready_o(core_rom_load_ready),
    .rom_load_offset_i(arb_rom_load_offset),
    .rom_load_data_i(arb_rom_load_data),
    .display_valid_o(),
    .display_x_o(),
    .display_y_o(),
    .display_pixel_o(),
    .framebuffer_scan_addr_i(core_fb_scan_addr),
    .framebuffer_scan_pixel_o(core_fb_scan_pixel),
    .framebuffer_o(core_framebuffer),
    .pc_o(pc_o),
    .debug_status_o(core_debug_status),
    .scb_hfsr_o(core_scb_hfsr),
    .scb_cfsr_o(core_scb_cfsr),
    .scb_mmfar_o(core_scb_mmfar),
    .scb_bfar_o(core_scb_bfar),
    .scb_shcsr_o(core_scb_shcsr),
    .scb_dfsr_o(core_scb_dfsr),
    .scb_afsr_o(core_scb_afsr),
    .sound_active_o(sound_active_o),
    .halted_o(halted_o)
  );

  assign framebuffer_o = core_framebuffer;

  chip8_dma2d_engine u_dma2d (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .framebuffer_i(core_framebuffer),
    .framebuffer_o(dma2d_framebuffer),
    .irq_done_o(irq_dma2d_done),
    .irq_error_o(irq_dma2d_error),
    .reg_valid_i(dma2d_valid),
    .reg_we_i(dma2d_we),
    .reg_addr_i(dma2d_addr),
    .reg_wdata_i(dma2d_wdata),
    .reg_wstrb_i(dma2d_wstrb),
    .reg_ready_o(dma2d_ready),
    .reg_rdata_o(dma2d_rdata)
  );

  chip8_dcmipp_pipeline u_dcmipp (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .framebuffer_i(dma2d_framebuffer),
    .framebuffer_o(dcmipp_framebuffer),
    .pixel_valid_o(dcmipp_pixel_valid),
    .pixel_x_o(dcmipp_pixel_x),
    .pixel_y_o(dcmipp_pixel_y),
    .pixel_o(),
    .irq_frame_o(irq_dcmipp_frame),
    .cam_valid_i(1'b0),
    .cam_hsync_i(1'b0),
    .cam_vsync_i(1'b0),
    .cam_ycbcr_i(CHIP8_AXI_IDLE_CAMERA_SAMPLE),
    .reg_valid_i(dcmipp_valid),
    .reg_we_i(dcmipp_we),
    .reg_addr_i(dcmipp_addr),
    .reg_wdata_i(dcmipp_wdata),
    .reg_wstrb_i(dcmipp_wstrb),
    .reg_ready_o(dcmipp_ready),
    .reg_rdata_o(dcmipp_rdata)
  );

  chip8_video_accel #(
    .DEFAULT_BACKEND(VIDEO_BACKEND)
  ) u_video_remote (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .framebuffer_i(dcmipp_framebuffer),
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
    .irq_frame_done_o(irq_video_done),
    .irq_vblank_o(irq_video_vblank),
    .irq_error_o(irq_video_error),
    .dma_done_o(video_dma_done),
    .reg_valid_i(video_valid),
    .reg_we_i(video_we),
    .reg_addr_i(video_addr),
    .reg_wdata_i(video_wdata),
    .reg_wstrb_i(video_wstrb),
    .reg_ready_o(video_ready),
    .reg_rdata_o(video_rdata)
  );

  chip8_dma_regs u_dma_regs (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .key_dma_done_i(key_dma_done),
    .key_dma_overflow_i(irq_key_overflow),
    .video_dma_done_i(video_dma_done),
    .video_dma_error_i(irq_video_error),
    .dma_error_irq_o(dma_error_irq),
    .reg_valid_i(dma_valid),
    .reg_we_i(dma_we),
    .reg_addr_i(dma_addr),
    .reg_wdata_i(dma_wdata),
    .reg_wstrb_i(dma_wstrb),
    .reg_ready_o(dma_ready),
    .reg_rdata_o(dma_rdata)
  );

  assign irq_sd_done = sd_boot_done;
  assign irq_sd_error = sd_boot_error;

  assign irq_sources[chip8_axi_pkg::IRQ_KEYPAD_EVENT]     = irq_key_event;
  assign irq_sources[chip8_axi_pkg::IRQ_KEYPAD_OVERFLOW]  = irq_key_overflow;
  assign irq_sources[chip8_axi_pkg::IRQ_VIDEO_FRAME_DONE] = irq_video_done;
  assign irq_sources[chip8_axi_pkg::IRQ_VIDEO_VBLANK]     = irq_video_vblank;
  assign irq_sources[chip8_axi_pkg::IRQ_VIDEO_ERROR]      = irq_video_error;
  assign irq_sources[chip8_axi_pkg::IRQ_KEY_DMA_DONE]     = key_dma_done;
  assign irq_sources[chip8_axi_pkg::IRQ_VIDEO_DMA_DONE]   = video_dma_done;
  assign irq_sources[chip8_axi_pkg::IRQ_DMA_ERROR]        = dma_error_irq;
  assign irq_sources[chip8_axi_pkg::IRQ_SD_DONE]          = irq_sd_done;
  assign irq_sources[chip8_axi_pkg::IRQ_SD_ERROR]         = irq_sd_error;
  assign irq_sources[chip8_axi_pkg::IRQ_BOOT_DONE]        = irq_boot_done;
  assign irq_sources[chip8_axi_pkg::IRQ_BOOT_ERROR]       = irq_boot_error;
  assign irq_sources[chip8_axi_pkg::IRQ_UART_RX]          = irq_uart_rx;
  assign irq_sources[chip8_axi_pkg::IRQ_DMA2D_DONE]       = irq_dma2d_done;
  assign irq_sources[chip8_axi_pkg::IRQ_DMA2D_ERROR]      = irq_dma2d_error;
  assign irq_sources[chip8_axi_pkg::IRQ_DCMIPP_FRAME]     = irq_dcmipp_frame;

  chip8_irq_controller #(
    .IRQ_COUNT(16)
  ) u_irq_controller (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .irq_sources_i(irq_sources),
    .irq_o(irq_o),
    .reg_valid_i(irq_valid),
    .reg_we_i(irq_we),
    .reg_addr_i(irq_addr),
    .reg_wdata_i(irq_wdata),
    .reg_wstrb_i(irq_wstrb),
    .reg_ready_o(irq_ready),
    .reg_rdata_o(irq_rdata)
  );

  assign debug_ready = debug_valid;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    unique case (debug_addr)
      DEBUG_STATUS_OFFSET: debug_rdata = {4'h0, usb_log_valid_o, sd_boot_busy,
        core_rst_n, dcmipp_pixel_valid, key_valid, halted_o, key_code,
        pc_o, dcmipp_pixel_y[2:0], dcmipp_pixel_x[2:0]};
      DEBUG_CORE_STATUS_OFFSET: debug_rdata = core_debug_status;
      DEBUG_SCB_SHCSR_OFFSET: debug_rdata = core_scb_shcsr;
      DEBUG_SCB_CFSR_OFFSET: debug_rdata = core_scb_cfsr;
      DEBUG_SCB_HFSR_OFFSET: debug_rdata = core_scb_hfsr;
      DEBUG_SCB_DFSR_OFFSET: debug_rdata = core_scb_dfsr;
      DEBUG_SCB_MMFAR_OFFSET: debug_rdata = core_scb_mmfar;
      DEBUG_SCB_BFAR_OFFSET: debug_rdata = core_scb_bfar;
      DEBUG_SCB_AFSR_OFFSET: debug_rdata = core_scb_afsr;
      default: debug_rdata = '0;
    endcase
  end

endmodule

`default_nettype wire

// EOF

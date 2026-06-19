// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tb_chip8_top.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Tb chip8 top.
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

module tb_chip8_top;
  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic clk;
  logic rst_n;
  logic [15:0] keys;
  logic display_valid;
  logic [5:0] display_x;
  logic [4:0] display_y;
  logic display_pixel;
  logic [2047:0] framebuffer;
  logic [11:0] pc;
  logic [31:0] debug_status;
  logic [31:0] scb_hfsr;
  logic [31:0] scb_cfsr;
  logic [31:0] scb_mmfar;
  logic [31:0] scb_bfar;
  logic [31:0] scb_shcsr;
  logic [31:0] scb_dfsr;
  logic [31:0] scb_afsr;
  logic sound_active;
  logic halted;
  logic rom_load_valid;
  logic rom_load_ready;
  logic [11:0] rom_load_offset;
  logic [7:0] rom_load_data;
  logic [7:0] rom_image [0:4095];
  int draw_events;
  int lit_pixels;
  int max_cycles;
  int rom_size;
  bit generic_rom;
  bit trace_display;
  string rom_file;

  chip8_top dut (
  .clk_i(clk),
  .rst_ni(rst_n),
  .keys_i(keys),
  .rom_load_valid_i(rom_load_valid),
  .rom_load_ready_o(rom_load_ready),
  .rom_load_offset_i(rom_load_offset),
  .rom_load_data_i(rom_load_data),
  .display_valid_o(display_valid),
  .display_x_o(display_x),
  .display_y_o(display_y),
  .display_pixel_o(display_pixel),
  .framebuffer_o(framebuffer),
  .pc_o(pc),
  .debug_status_o(debug_status),
  .scb_hfsr_o(scb_hfsr),
  .scb_cfsr_o(scb_cfsr),
  .scb_mmfar_o(scb_mmfar),
  .scb_bfar_o(scb_bfar),
  .scb_shcsr_o(scb_shcsr),
  .scb_dfsr_o(scb_dfsr),
  .scb_afsr_o(scb_afsr),
  .sound_active_o(sound_active),
  .halted_o(halted)
  );

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  always #5 clk <= !clk;

  // ------------------------------------------------------------
  // Testbench tasks
  // ------------------------------------------------------------

  task automatic read_rom_image;
  int fd;
  int scanned;
  logic [7:0] byte_value;
  begin
    if (!$value$plusargs("CHIP8_ROM_MEM=%s", rom_file)) begin
    rom_file = "validation/programs/chip8/smoke.mem";
    end

    rom_size = '0;
    fd = $fopen(rom_file, "r");
    assert (fd != 0) else $fatal(1, "failed to open ROM mem: %s",
    rom_file);

    while (!$feof(fd)) begin
    scanned = $fscanf(fd, "%h\n", byte_value);
    if (scanned == 1) begin
      assert (rom_size < 4096) else $fatal(1,
      "ROM mem too large: %s", rom_file);
      rom_image[rom_size] = byte_value;
      rom_size++;
    end
    end
    $fclose(fd);
    assert (rom_size > 0) else $fatal(1, "empty ROM mem: %s",
    rom_file);
  end
  endtask

  task automatic load_rom_via_interface;
  int offset;
  begin
    for (offset = '0; offset < rom_size; offset++) begin
    rom_load_offset = 12'(offset);
    rom_load_data = rom_image[offset];
    rom_load_valid = 1'b1;
    do begin
      @(posedge clk);
    end while (!rom_load_ready);
    end
    rom_load_valid = 1'b0;
    rom_load_offset = '0;
    rom_load_data = '0;
    repeat (2) @(posedge clk);
  end
  endtask

  initial begin
  clk = '0;
  rst_n = '0;
  keys = '0;
  rom_load_valid = '0;
  rom_load_offset = '0;
  rom_load_data = '0;
  draw_events = '0;
  read_rom_image();
  generic_rom = $test$plusargs("GENERIC_ROM");
  trace_display = $test$plusargs("TRACE_DISPLAY");
  if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) begin
    max_cycles = generic_rom ? 2500 : 200;
  end
  repeat (2) @(posedge clk);
  rst_n = '1;
  load_rom_via_interface();
  rst_n = '0;
  repeat (2) @(posedge clk);
  rst_n = '1;

  repeat (max_cycles) begin
    @(posedge clk);
    assert (!$isunknown(pc)) else $fatal(1, "CHIP-8 pc unknown");
    assert (!halted) else $fatal(1, "CHIP-8 unexpectedly halted");
    if (display_valid) begin
    draw_events++;
    assert ({1'b0, display_x} < 7'd64) else $fatal(1,
      "display x out of range");
    assert ({1'b0, display_y} < 6'd32) else $fatal(1,
      "display y out of range");
    assert (display_pixel === 1'b0 || display_pixel === 1'b1)
      else $fatal(1, "display pixel unknown");
    if (trace_display) begin
      $display(
      "draw[%0d]: pc=%03h x=%0d y=%0d pixel=%0b",
      draw_events,
      pc,
      display_x,
      display_y,
      display_pixel
      );
    end
    end
    assert (sound_active === 1'b0 || sound_active === 1'b1) else $fatal(
    1, "sound active unknown");
    assert (!$isunknown(debug_status)) else $fatal(1,
    "debug status unknown");
    assert (!$isunknown({scb_hfsr, scb_cfsr, scb_shcsr, scb_dfsr,
    scb_afsr})) else $fatal(1, "SCB fault status unknown");
    assert (scb_mmfar == 32'h00000000) else $fatal(1,
    "unexpected MMFAR value");
    assert (scb_bfar == 32'h00000000) else $fatal(1,
    "unexpected BFAR value");
  end

  lit_pixels = '0;
  for (int idx = '0; idx < 2048; idx++) begin
    lit_pixels += int'(framebuffer[idx]);
  end

  if (!generic_rom) begin
    assert (draw_events >= 22) else $fatal(1,
    "not enough display transmissions");
    assert (lit_pixels == 22) else $fatal(1,
    "unexpected lit pixel count: %0d", lit_pixels);
    assert (pc == 12'h214 || pc == 12'h216) else $fatal(1,
    "unexpected CHIP-8 loop PC: %03h", pc);
  end else begin
    assert (!$isunknown(framebuffer)) else $fatal(1,
    "framebuffer unknown");
    $display(
    "ROM done: cyc=%0d pc=%03h draws=%0d lit=%0d",
    max_cycles,
    pc,
    draw_events,
    lit_pixels
    );
  end
  $finish;
  end
endmodule

`default_nettype wire

// EOF

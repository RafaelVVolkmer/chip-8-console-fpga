// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tb_chip8_components.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Tb chip8 components.
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

module tb_chip8_components;
  localparam int unsigned CHIP8_NUM_REGS = 16;
  localparam int unsigned CHIP8_STACK_DEPTH = 16;
  localparam int unsigned CHIP8_FRAMEBUFFER_BITS = 2048;

  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic clk;
  logic rst_n;

  chip8_alu_pkg::chip8_alu_op_t alu_op;
  logic [7:0] alu_a;
  logic [7:0] alu_b;
  logic [7:0] alu_y;
  logic alu_flag;

  logic [15:0] opcode;
  logic [3:0] opcode_class;
  logic [3:0] x_idx;
  logic [3:0] y_idx;
  logic [3:0] n;
  logic [7:0] kk;
  logic [11:0] nnn;
  chip8_core_pkg::chip8_decoded_t decoded;

  logic [11:0] pc_in;
  logic [11:0] pc_plus_2;
  logic [11:0] pc_plus_4;
  logic [11:0] jump_v0;
  logic [5:0] datapath_draw_x;
  logic [4:0] datapath_draw_y;
  logic [11:0] fetch_hi_addr;
  logic [11:0] fetch_lo_addr;
  logic [15:0] fetched_opcode;

  logic [15:0] keys;
  logic any_key;
  logic [3:0] first_key;
  logic selected_key;
  logic [15:0] sampled_keys;

  logic [3:0] io_addr;
  logic [7:0] io_rdata;

  logic stack_push;
  logic stack_pop;
  logic [11:0] stack_push_data;
  logic [11:0] stack_pop_data;
  logic stack_overflow;
  logic stack_underflow;

  logic delay_we;
  logic sound_we;
  logic timer_tick;
  logic [7:0] delay_value;
  logic [7:0] sound_value;
  logic sound_active;
  logic fast_rst_n;
  logic fast_tick;

  logic fb_clear;
  logic fb_draw_we;
  logic [5:0] fb_x;
  logic [4:0] fb_y;
  logic fb_old;
  logic fb_new;
  logic [2047:0] framebuffer;
  logic [10:0] fb_scan_addr;
  logic fb_scan_pixel;
  logic collision;
  logic [3:0] bcd_hundreds;
  logic [3:0] bcd_tens;
  logic [3:0] bcd_ones;

  logic reg_we;
  logic [3:0] reg_x_addr;
  logic [3:0] reg_y_addr;
  logic [3:0] reg_dbg_addr;
  logic [3:0] reg_waddr;
  logic [7:0] reg_wdata;
  logic [7:0] reg_x_data;
  logic [7:0] reg_y_data;
  logic [7:0] reg_dbg_data;
  logic [7:0] reg_v0_data;
  logic [7:0] reg_vf_data;

  logic mem_we;
  logic [11:0] mem_raddr0;
  logic [11:0] mem_raddr1;
  logic [11:0] mem_waddr;
  logic [7:0] mem_wdata;
  logic [7:0] mem_rdata0;
  logic [7:0] mem_rdata1;

  logic [7:0] sprite_byte;
  logic [2:0] sprite_bit;
  logic [5:0] sprite_x;
  logic [4:0] sprite_y;
  logic [3:0] sprite_row;
  logic sprite_on;
  logic [5:0] draw_x;
  logic [4:0] draw_y;

  chip8_alu u_alu (
  .op_i(alu_op),
  .a_i(alu_a),
  .b_i(alu_b),
  .y_o(alu_y),
  .flag_o(alu_flag)
  );

  chip8_decode u_decode (
  .opcode_i(opcode),
  .class_o(opcode_class),
  .x_o(x_idx),
  .y_o(y_idx),
  .n_o(n),
  .kk_o(kk),
  .nnn_o(nnn),
  .decoded_o(decoded)
  );

  chip8_datapath u_datapath (
  .draw_x_value_i(alu_a[5:0]),
  .draw_y_value_i(alu_b[4:0]),
  .v0_i(alu_a),
  .nnn_i(nnn),
  .pc_i(pc_in),
  .pc_plus_2_o(pc_plus_2),
  .pc_plus_4_o(pc_plus_4),
  .jump_v0_o(jump_v0),
  .draw_x_o(datapath_draw_x),
  .draw_y_o(datapath_draw_y)
  );

  chip8_fetch u_fetch (
  .pc_i(pc_in),
  .mem_hi_i(alu_a),
  .mem_lo_i(alu_b),
  .raddr_hi_o(fetch_hi_addr),
  .raddr_lo_o(fetch_lo_addr),
  .opcode_o(fetched_opcode)
  );

  chip8_keypad u_keypad (
  .keys_i(keys),
  .select_i(alu_a[3:0]),
  .selected_pressed_o(selected_key),
  .any_pressed_o(any_key),
  .first_pressed_o(first_key),
  .keys_o(sampled_keys)
  );

  chip8_io_mux u_io_mux (
  .addr_i(io_addr),
  .delay_i(delay_value),
  .sound_i(sound_value),
  .keys_i(sampled_keys),
  .key_any_i(any_key),
  .key_first_i(first_key),
  .rdata_o(io_rdata)
  );

  chip8_stack u_stack (
  .clk_i(clk),
  .rst_ni(rst_n),
  .push_we_i(stack_push),
  .pop_we_i(stack_pop),
  .push_data_i(stack_push_data),
  .pop_data_o(stack_pop_data),
  .overflow_o(stack_overflow),
  .underflow_o(stack_underflow)
  );

  chip8_regfile u_regfile (
  .clk_i(clk),
  .rst_ni(rst_n),
  .x_addr_i(reg_x_addr),
  .y_addr_i(reg_y_addr),
  .dbg_addr_i(reg_dbg_addr),
  .we_i(reg_we),
  .waddr_i(reg_waddr),
  .wdata_i(reg_wdata),
  .x_data_o(reg_x_data),
  .y_data_o(reg_y_data),
  .dbg_data_o(reg_dbg_data),
  .v0_data_o(reg_v0_data),
  .vf_data_o(reg_vf_data)
  );

  chip8_delay_timer u_delay_timer (
  .clk_i(clk),
  .rst_ni(rst_n),
  .tick_60hz_i(timer_tick),
  .we_i(delay_we),
  .wdata_i(alu_a),
  .value_o(delay_value)
  );

  chip8_sound_timer u_sound_timer (
  .clk_i(clk),
  .rst_ni(rst_n),
  .tick_60hz_i(timer_tick),
  .we_i(sound_we),
  .wdata_i(alu_b),
  .value_o(sound_value),
  .active_o(sound_active)
  );

  chip8_timer_60hz #(
  .CLK_HZ(4),
  .TICK_HZ(2)
  ) u_fast_tick (
  .clk_i(clk),
  .rst_ni(fast_rst_n),
  .tick_o(fast_tick)
  );

  chip8_framebuffer u_framebuffer (
  .clk_i(clk),
  .rst_ni(rst_n),
  .clear_i(fb_clear),
  .draw_we_i(fb_draw_we),
  .draw_x_i(fb_x),
  .draw_y_i(fb_y),
  .scan_addr_i(fb_scan_addr),
  .old_pixel_o(fb_old),
  .new_pixel_o(fb_new),
  .scan_pixel_o(fb_scan_pixel),
  .framebuffer_o(framebuffer)
  );

  chip8_collision_unit u_collision (
  .draw_we_i(fb_draw_we),
  .old_pixel_i(fb_old),
  .collision_o(collision)
  );

  chip8_bcd u_bcd (
  .binary_i(alu_a),
  .hundreds_o(bcd_hundreds),
  .tens_o(bcd_tens),
  .ones_o(bcd_ones)
  );

  chip8_memory u_memory (
  .clk_i(clk),
  .rst_ni(rst_n),
  .raddr0_i(mem_raddr0),
  .raddr1_i(mem_raddr1),
  .we_i(mem_we),
  .waddr_i(mem_waddr),
  .wdata_i(mem_wdata),
  .rdata0_o(mem_rdata0),
  .rdata1_o(mem_rdata1)
  );

  chip8_sprite_blitter u_blitter (
  .sprite_byte_i(sprite_byte),
  .bit_i(sprite_bit),
  .base_x_i(sprite_x),
  .base_y_i(sprite_y),
  .row_i(sprite_row),
  .pixel_on_o(sprite_on),
  .draw_x_o(draw_x),
  .draw_y_o(draw_y)
  );

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  always #5 clk <= !clk;

  // ------------------------------------------------------------
  // Testbench tasks
  // ------------------------------------------------------------

  task automatic tick;
  begin
    @(posedge clk);
    #1;
  end
  endtask

  task automatic expect_alu(
  input chip8_alu_pkg::chip8_alu_op_t op,
  input logic [7:0] a,
  input logic [7:0] b,
  input logic [7:0] y,
  input logic flag
  );
  begin
    alu_op = op;
    alu_a = a;
    alu_b = b;
    #1;
    assert (alu_y == y) else $fatal(1,
    "ALU y mismatch op=%0d a=%02h b=%02h got=%02h exp=%02h", op, a,
      b, alu_y, y);
    assert (alu_flag == flag) else $fatal(1,
    "ALU flag mismatch op=%0d a=%02h b=%02h got=%0b exp=%0b", op,
      a, b, alu_flag, flag);
  end
  endtask

  task automatic expect_reg(
  input logic [3:0] addr,
  input logic [7:0] expected
  );
  begin
    reg_x_addr = addr;
    reg_y_addr = addr;
    reg_dbg_addr = addr;
    #1;
    assert (reg_x_data == expected) else $fatal(1,
      "regfile x mismatch addr=%0d got=%02h exp=%02h", addr, reg_x_data,
      expected);
    assert (reg_y_data == expected) else $fatal(1,
      "regfile y mismatch addr=%0d got=%02h exp=%02h", addr, reg_y_data,
      expected);
    assert (reg_dbg_data == expected) else $fatal(1,
      "regfile dbg mismatch addr=%0d got=%02h exp=%02h", addr,
      reg_dbg_data, expected);
  end
  endtask

  task automatic draw_pixel(
  input logic [5:0] x,
  input logic [4:0] y
  );
  begin
    fb_x = x;
    fb_y = y;
    fb_draw_we = '1;
    tick();
    fb_draw_we = '0;
    #1;
  end
  endtask

  initial begin
  int unsigned alu_a_idx;
  int unsigned alu_b_idx;
  int unsigned reg_idx;
  int unsigned stack_idx;
  logic [7:0] alu_a_val;
  logic [7:0] alu_b_val;

  clk = '0;
  rst_n = '0;
  alu_op = chip8_alu_pkg::CHIP8_ALU_MOV;
  alu_a = '0;
  alu_b = '0;
  opcode = '0;
  pc_in = '0;
  keys = '0;
  io_addr = '0;
  stack_push = '0;
  stack_pop = '0;
  stack_push_data = '0;
  delay_we = '0;
  sound_we = '0;
  timer_tick = '0;
  fast_rst_n = '0;
  fb_clear = '0;
  fb_draw_we = '0;
  fb_x = '0;
  fb_y = '0;
  fb_scan_addr = '0;
  sprite_byte = '0;
  sprite_bit = '0;
  sprite_x = '0;
  sprite_y = '0;
  sprite_row = '0;
  reg_we = '0;
  reg_x_addr = '0;
  reg_y_addr = '0;
  reg_dbg_addr = '0;
  reg_waddr = '0;
  reg_wdata = '0;
  mem_we = '0;
  mem_raddr0 = '0;
  mem_raddr1 = 12'h001;
  mem_waddr = '0;
  mem_wdata = '0;

  repeat (2) tick();
  rst_n = '1;
  tick();

  expect_alu(chip8_alu_pkg::CHIP8_ALU_MOV, 8'h12, 8'h34, 8'h34, 1'b0);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_OR, 8'hf0, 8'h0f, 8'hff, 1'b0);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_AND, 8'hf0, 8'h0f, 8'h00, 1'b0);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_XOR, 8'hAA, 8'h55, 8'hff, 1'b0);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_ADD, 8'hff, 8'h01, 8'h00, 1'b1);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_ADD_IMM, 8'h01, 8'h02, 8'h03, 1'b0);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_SUB, 8'h10, 8'h01, 8'h0f, 1'b1);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_SUB, 8'h00, 8'h01, 8'hff, 1'b0);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_RSUB, 8'h02, 8'h10, 8'h0e, 1'b1);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_SHR, 8'h81, 8'h00, 8'h40, 1'b1);
  expect_alu(chip8_alu_pkg::CHIP8_ALU_SHL, 8'h80, 8'h00, 8'h00, 1'b1);

  for (alu_a_idx = 0; alu_a_idx < 256; alu_a_idx += 17) begin
    for (alu_b_idx = 0; alu_b_idx < 256; alu_b_idx += 29) begin
      alu_a_val = alu_a_idx[7:0];
      alu_b_val = alu_b_idx[7:0];
      expect_alu(
        chip8_alu_pkg::CHIP8_ALU_OR,
        alu_a_val,
        alu_b_val,
        alu_a_val | alu_b_val,
        1'b0
      );
      expect_alu(
        chip8_alu_pkg::CHIP8_ALU_AND,
        alu_a_val,
        alu_b_val,
        alu_a_val & alu_b_val,
        1'b0
      );
      expect_alu(
        chip8_alu_pkg::CHIP8_ALU_XOR,
        alu_a_val,
        alu_b_val,
        alu_a_val ^ alu_b_val,
        1'b0
      );
      expect_alu(
        chip8_alu_pkg::CHIP8_ALU_ADD,
        alu_a_val,
        alu_b_val,
        alu_a_val + alu_b_val,
        (alu_a_idx + alu_b_idx) > 255
      );
      expect_alu(
        chip8_alu_pkg::CHIP8_ALU_SUB,
        alu_a_val,
        alu_b_val,
        alu_a_val - alu_b_val,
        alu_a_idx >= alu_b_idx
      );
      expect_alu(
        chip8_alu_pkg::CHIP8_ALU_RSUB,
        alu_a_val,
        alu_b_val,
        alu_b_val - alu_a_val,
        alu_b_idx >= alu_a_idx
      );
    end
  end

  alu_a = 8'd255;
  #1 assert (bcd_hundreds == 4'd2 && bcd_tens == 4'd5 && bcd_ones == 4'd5)
    ;
  alu_a = 8'd42;
  #1 assert (bcd_hundreds == 4'd0 && bcd_tens == 4'd4 && bcd_ones == 4'd2)
    ;

  opcode = 16'hd12f;
  #1;
  assert (opcode_class == 4'hd && x_idx == 4'h1 && y_idx == 4'h2 && n ==
    4'hf && kk == 8'h2f && nnn == 12'h12f);
  pc_in = 12'hfff;
  alu_a = 8'hab;
  alu_b = 8'hcd;
  #1;
  assert (fetch_hi_addr == 12'hfff && fetch_lo_addr == 12'h000 &&
    fetched_opcode == 16'habcd);
  assert (pc_plus_2 == 12'h001 && pc_plus_4 == 12'h003);
  assert (jump_v0 == ((nnn + 12'hab) & 12'hfff));
  assert (datapath_draw_x == 6'h2b && datapath_draw_y == 5'h0d);

  keys = 16'h0088;
  alu_a = 8'h07;
  #1;
  assert (any_key && selected_key && first_key == 4'h3 && sampled_keys ==
    keys);
  io_addr = chip8_periph_pkg::CHIP8_IO_DELAY;
  #1 assert (io_rdata == delay_value);
  io_addr = chip8_periph_pkg::CHIP8_IO_SOUND;
  #1 assert (io_rdata == sound_value);
  io_addr = chip8_periph_pkg::CHIP8_IO_KEYS_LO;
  #1 assert (io_rdata == 8'h88);
  io_addr = chip8_periph_pkg::CHIP8_IO_KEYS_HI;
  #1 assert (io_rdata == 8'h00);
  io_addr = chip8_periph_pkg::CHIP8_IO_KEY_ANY;
  #1 assert (io_rdata == 8'h01);
  io_addr = chip8_periph_pkg::CHIP8_IO_KEY_FIRST;
  #1 assert (io_rdata == 8'h03);

  stack_push_data = 12'h234;
  stack_push = '1;
  tick();
  assert (!stack_overflow && !stack_underflow);
  stack_push_data = 12'h345;
  tick();
  assert (!stack_overflow && !stack_underflow);
  stack_push = '0;
  #1 assert (stack_pop_data == 12'h345);
  stack_pop = '1;
  tick();
  assert (!stack_overflow && !stack_underflow);
  #1 assert (stack_pop_data == 12'h234);
  tick();
  assert (!stack_overflow && !stack_underflow);
  stack_pop = '0;
  tick();
  stack_pop = '1;
  tick();
  assert (stack_underflow && !stack_overflow);
  stack_pop = '0;
  tick();

  stack_push = '1;
  for (stack_idx = 0; stack_idx < CHIP8_STACK_DEPTH; stack_idx++) begin
    stack_push_data = 12'(stack_idx);
    tick();
    assert (!stack_overflow && !stack_underflow);
  end
  stack_push_data = 12'habc;
  tick();
  assert (stack_overflow && !stack_underflow);
  stack_push = '0;
  stack_pop = '1;
  for (stack_idx = 0; stack_idx < CHIP8_STACK_DEPTH; stack_idx++) begin
    tick();
    assert (!stack_overflow && !stack_underflow);
  end
  stack_pop = '0;

  reg_we = '1;
  reg_waddr = 4'h1;
  reg_wdata = 8'h11;
  tick();
  reg_waddr = 4'h2;
  reg_wdata = 8'h22;
  tick();
  reg_we = '0;
  reg_x_addr = 4'h1;
  reg_y_addr = 4'h2;
  reg_dbg_addr = 4'h2;
  #1 assert (reg_x_data == 8'h11 && reg_y_data == 8'h22 &&
    reg_dbg_data == 8'h22);
  assert (reg_v0_data == 8'h00 && reg_vf_data == 8'h00);

  reg_we = '1;
  for (reg_idx = 0; reg_idx < CHIP8_NUM_REGS; reg_idx++) begin
    reg_waddr = reg_idx[3:0];
    reg_wdata = (reg_idx[7:0] << 4) ^ 8'h5a;
    tick();
  end
  reg_we = '0;
  for (reg_idx = 0; reg_idx < CHIP8_NUM_REGS; reg_idx++) begin
    expect_reg(reg_idx[3:0], (reg_idx[7:0] << 4) ^ 8'h5a);
  end
  assert (reg_v0_data == 8'h5a && reg_vf_data == 8'hAA);

  alu_a = 8'h03;
  alu_b = 8'h02;
  delay_we = '1;
  sound_we = '1;
  tick();
  delay_we = '0;
  sound_we = '0;
  assert (delay_value == 8'h03 && sound_value == 8'h02 && sound_active);
  timer_tick = '1;
  tick();
  assert (delay_value == 8'h02 && sound_value == 8'h01);
  tick();
  assert (delay_value == 8'h01 && sound_value == 8'h00 && !sound_active);
  tick();
  assert (delay_value == 8'h00 && sound_value == 8'h00);
  timer_tick = '0;

  fast_rst_n = '0;
  tick();
  assert (!fast_tick);
  fast_rst_n = '1;
  tick();
  assert (!fast_tick);
  tick();
  assert (fast_tick);
  tick();
  assert (!fast_tick);

  fb_x = 6'd63;
  fb_y = 5'd31;
  assert (!fb_old && fb_new);
  fb_draw_we = '1;
  tick();
  assert (fb_old && !fb_new && framebuffer[2047]);
  assert (collision);
  fb_draw_we = '0;
  #1 assert (!collision);
  fb_clear = '1;
  tick();
  fb_clear = '0;
  assert (framebuffer == '0);
  assert (!fb_scan_pixel);

  draw_pixel(6'd0, 5'd0);
  draw_pixel(6'd1, 5'd0);
  draw_pixel(6'd0, 5'd8);
  draw_pixel(6'd63, 5'd31);
  fb_scan_addr = 11'd0;
  #1 assert (fb_scan_pixel && framebuffer[0]);
  fb_scan_addr = 11'd1;
  #1 assert (fb_scan_pixel && framebuffer[1]);
  fb_scan_addr = 11'd512;
  #1 assert (fb_scan_pixel && framebuffer[512]);
  fb_scan_addr = 11'd2047;
  #1 assert (fb_scan_pixel && framebuffer[2047]);
  draw_pixel(6'd0, 5'd8);
  fb_scan_addr = 11'd512;
  #1 assert (!fb_scan_pixel && !framebuffer[512]);
  fb_clear = '1;
  tick();
  fb_clear = '0;
  assert (framebuffer == '0);

  sprite_byte = 8'b1000_0001;
  sprite_x = 6'd63;
  sprite_y = 5'd31;
  sprite_row = 4'd1;
  sprite_bit = '0;
  #1 assert (sprite_on && draw_x == 6'd63 && draw_y == 5'd0);
  sprite_bit = 3'd7;
  #1 assert (sprite_on && draw_x == 6'd6 && draw_y == 5'd0);
  sprite_bit = 3'd3;
  #1 assert (!sprite_on);

  mem_we = '1;
  mem_waddr = 12'h234;
  mem_wdata = 8'h5a;
  tick();
  mem_we = '0;
  mem_raddr0 = '0;
  mem_raddr1 = 12'h234;
  tick();
  tick();
  assert (mem_rdata0 == 8'hf0);
  assert (mem_rdata1 == 8'h5a);
  mem_raddr0 = 12'h005;
  tick();
  assert (mem_rdata0 == 8'h20);

  $display("CHIP-8 component stress PASS");
  $finish;
  end
endmodule

`default_nettype wire

// EOF

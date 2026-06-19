// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_components_formal.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 core block suite.
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

module chip8_components_formal;
  localparam logic [11:0] FORMAL_ADDR_MASK = 12'hfff;
  localparam int unsigned FORMAL_CHIP8_WIDTH = 64;
  localparam int unsigned FORMAL_CHIP8_HEIGHT = 32;

  (* anyseq *) logic clk;
  (* anyseq *) logic rst_n;
  (* anyconst *) chip8_alu_pkg::chip8_alu_op_t alu_op;
  (* anyconst *) logic [7:0] a;
  (* anyconst *) logic [7:0] b;
  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic [7:0] alu_y;
  logic alu_flag;

  (* anyconst *) logic [15:0] opcode;
  logic [3:0] opcode_class;
  logic [3:0] x_idx;
  logic [3:0] y_idx;
  logic [3:0] n;
  logic [7:0] kk;
  logic [11:0] nnn;
  chip8_core_pkg::chip8_decoded_t decoded;

  (* anyconst *) logic [11:0] pc;
  logic [11:0] fetch_hi_addr;
  logic [11:0] fetch_lo_addr;
  logic [15:0] fetched_opcode;

  (* anyconst *) logic [7:0] sprite_byte;
  (* anyconst *) logic [2:0] sprite_bit;
  (* anyconst *) logic [5:0] base_x;
  (* anyconst *) logic [4:0] base_y;
  (* anyconst *) logic [3:0] sprite_row;
  logic sprite_on;
  logic [5:0] draw_x;
  logic [4:0] draw_y;
  logic skip;

  (* anyconst *) logic [15:0] keys;
  (* anyconst *) logic [3:0] key_select;
  logic key_any;
  logic [3:0] key_first;
  logic key_selected;
  logic [15:0] key_sample;

  (* anyconst *) logic [3:0] io_addr;
  logic [7:0] io_rdata;

  (* anyconst *) logic timer_tick;
  (* anyconst *) logic timer_we;
  logic [7:0] delay_value;
  logic [7:0] sound_value;
  logic sound_active;

  (* anyconst *) logic fb_clear;
  (* anyconst *) logic fb_draw_we;
  (* anyconst *) logic [5:0] fb_x;
  (* anyconst *) logic [4:0] fb_y;
  logic fb_old;
  logic fb_new;
  logic [2047:0] framebuffer;
  logic fb_scan_pixel;
  logic [3:0] bcd_hundreds;
  logic [3:0] bcd_tens;
  logic [3:0] bcd_ones;

  // ------------------------------------------------------------
  // Combinational checks
  // ------------------------------------------------------------

  always_comb begin
  if ($initstate) begin
    assume (!rst_n);
  end else begin
    assume (rst_n);
  end
  end

  chip8_alu u_alu (
  .op_i(alu_op),
  .a_i(a),
  .b_i(b),
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

  chip8_fetch u_fetch (
  .pc_i(pc),
  .mem_hi_i(a),
  .mem_lo_i(b),
  .raddr_hi_o(fetch_hi_addr),
  .raddr_lo_o(fetch_lo_addr),
  .opcode_o(fetched_opcode)
  );

  chip8_sprite_blitter u_blitter (
  .sprite_byte_i(sprite_byte),
  .bit_i(sprite_bit),
  .base_x_i(base_x),
  .base_y_i(base_y),
  .row_i(sprite_row),
  .pixel_on_o(sprite_on),
  .draw_x_o(draw_x),
  .draw_y_o(draw_y)
  );

  chip8_skip_unit u_skip_unit (
  .opcode_class_i(opcode_class),
  .vx_i(a),
  .vy_i(b),
  .kk_i(kk),
  .n_i(n),
  .skip_o(skip)
  );

  chip8_keypad u_keypad (
  .keys_i(keys),
  .select_i(key_select),
  .selected_pressed_o(key_selected),
  .any_pressed_o(key_any),
  .first_pressed_o(key_first),
  .keys_o(key_sample)
  );

  chip8_io_mux u_io_mux (
  .addr_i(io_addr),
  .delay_i(a),
  .sound_i(b),
  .keys_i(keys),
  .key_any_i(key_any),
  .key_first_i(key_first),
  .rdata_o(io_rdata)
  );

  chip8_delay_timer u_delay_timer (
  .clk_i(clk),
  .rst_ni(rst_n),
  .tick_60hz_i(timer_tick),
  .we_i(timer_we),
  .wdata_i(a),
  .value_o(delay_value)
  );

  chip8_sound_timer u_sound_timer (
  .clk_i(clk),
  .rst_ni(rst_n),
  .tick_60hz_i(timer_tick),
  .we_i(timer_we),
  .wdata_i(b),
  .value_o(sound_value),
  .active_o(sound_active)
  );

  chip8_framebuffer u_framebuffer (
  .clk_i(clk),
  .rst_ni(rst_n),
  .clear_i(fb_clear),
  .draw_we_i(fb_draw_we),
  .draw_x_i(fb_x),
  .draw_y_i(fb_y),
  .scan_addr_i(11'd0),
  .old_pixel_o(fb_old),
  .new_pixel_o(fb_new),
  .scan_pixel_o(fb_scan_pixel),
  .framebuffer_o(framebuffer)
  );

  chip8_bcd u_bcd (
  .binary_i(a),
  .hundreds_o(bcd_hundreds),
  .tens_o(bcd_tens),
  .ones_o(bcd_ones)
  );

  always_comb begin
  assert (opcode_class == opcode[15:12]);
  assert (x_idx == opcode[11:8]);
  assert (y_idx == opcode[7:4]);
  assert (n == opcode[3:0]);
  assert (kk == opcode[7:0]);
  assert (nnn == opcode[11:0]);

  assert (fetch_hi_addr == pc);
  assert (fetch_lo_addr == ((pc + 1'b1) & FORMAL_ADDR_MASK));
  assert (fetched_opcode == {a, b});

  assert (sprite_on == sprite_byte[7 - sprite_bit]);
  assert (draw_x < FORMAL_CHIP8_WIDTH);
  assert (draw_y < FORMAL_CHIP8_HEIGHT);
  assert (skip == (
    (opcode_class == 4'h3 && a == kk) ||
    (opcode_class == 4'h4 && a != kk) ||
    (opcode_class == 4'h5 && n == 4'h0 && a == b) ||
    (opcode_class == 4'h9 && n == 4'h0 && a != b)
  ));

  assert (key_sample == keys);
  assert (key_any == (keys != 16'h0000));
  assert (key_selected == keys[key_select]);
  assert (key_first[0] == |((keys & (~keys + 1'b1)) & 16'haaaa));
  assert (key_first[1] == |((keys & (~keys + 1'b1)) & 16'hcccc));
  assert (key_first[2] == |((keys & (~keys + 1'b1)) & 16'hf0f0));
  assert (key_first[3] == |((keys & (~keys + 1'b1)) & 16'hff00));

  if (io_addr == chip8_periph_pkg::CHIP8_IO_DELAY) assert (io_rdata == a);
  if (io_addr == chip8_periph_pkg::CHIP8_IO_SOUND) assert (io_rdata == b);
  if (io_addr == chip8_periph_pkg::CHIP8_IO_KEYS_LO) assert (io_rdata ==
    keys[7:0]);
  if (io_addr == chip8_periph_pkg::CHIP8_IO_KEYS_HI) assert (io_rdata ==
    keys[15:8]);
  if (io_addr == chip8_periph_pkg::CHIP8_IO_KEY_ANY) assert (io_rdata ==
    {7'h00, key_any});
  if (io_addr == chip8_periph_pkg::CHIP8_IO_KEY_FIRST) assert (
    io_rdata == {4'h0, key_first});
  if (
    io_addr != chip8_periph_pkg::CHIP8_IO_DELAY &&
    io_addr != chip8_periph_pkg::CHIP8_IO_SOUND &&
    io_addr != chip8_periph_pkg::CHIP8_IO_KEYS_LO &&
    io_addr != chip8_periph_pkg::CHIP8_IO_KEYS_HI &&
    io_addr != chip8_periph_pkg::CHIP8_IO_KEY_ANY &&
    io_addr != chip8_periph_pkg::CHIP8_IO_KEY_FIRST
  ) assert (io_rdata == 8'h00);

  assert (fb_old == framebuffer[{fb_y, 6'h00} + {5'h00, fb_x}]);
  assert (fb_new == !framebuffer[{fb_y, 6'h00} + {5'h00, fb_x}]);
  assert (({4'h0, bcd_hundreds} * 8'd100 + {4'h0, bcd_tens} * 8'd10 +
    {4'h0, bcd_ones}) == a);
  assert (bcd_hundreds <= 4'd2);
  assert (bcd_tens <= 4'd9);
  assert (bcd_ones <= 4'd9);
  assert (sound_active == (sound_value != 8'h00));

  if (alu_op == chip8_alu_pkg::CHIP8_ALU_MOV) assert (alu_y == b);
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_OR) assert (alu_y == (a | b));
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_AND) assert (alu_y == (a & b));
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_XOR) assert (alu_y == (a ^ b));
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_ADD || alu_op ==
    chip8_alu_pkg::CHIP8_ALU_ADD_IMM) begin
    assert ({alu_flag, alu_y} == ({1'b0, a} + {1'b0, b}));
  end
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_SUB) begin
    assert (alu_y == (a - b));
    assert (alu_flag == (a >= b));
  end
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_RSUB) begin
    assert (alu_y == (b - a));
    assert (alu_flag == (b >= a));
  end
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_SHR) begin
    assert (alu_y == {1'b0, a[7:1]});
    assert (alu_flag == a[0]);
  end
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_SHL) begin
    assert (alu_y == {a[6:0], 1'b0});
    assert (alu_flag == a[7]);
  end
  end
endmodule

`default_nettype wire

// EOF

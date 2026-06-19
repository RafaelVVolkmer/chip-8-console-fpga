// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_blocks_formal.sv
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

module chip8_blocks_formal (
  input logic clk,
  input logic rst_n
);
  localparam logic [11:0] FORMAL_ADDR_MASK = 12'hfff;
  localparam logic [11:0] FORMAL_IO_BASE = 12'hff0;
  localparam logic [5:0] FORMAL_SPRITE_X_MASK = 6'h3f;
  localparam logic [4:0] FORMAL_SPRITE_Y_MASK = 5'h1f;

  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

  logic past_valid = '0;

  (* anyconst *) chip8_alu_pkg::chip8_alu_op_t alu_op;
  (* anyconst *) logic [7:0] a;
  (* anyconst *) logic [7:0] b;
  logic [7:0] alu_y;
  logic alu_flag;
  logic [8:0] alu_sum;

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
  logic [11:0] pc_plus_2;
  logic [11:0] pc_plus_4;
  logic [11:0] jump_v0;
  logic [5:0] dp_draw_x;
  logic [4:0] dp_draw_y;

  logic skip_unit_skip;
  logic control_draw;
  logic control_wait_key;
  logic control_timer_write;
  logic control_memory_burst;
  logic control_uses_memory;
  logic control_uses_display;
  logic control_uses_timer;
  logic control_uses_keypad;
  logic control_legal;
  chip8_core_pkg::chip8_uop_t control_first_uop;

  logic [3:0] bcd_hundreds;
  logic [3:0] bcd_tens;
  logic [3:0] bcd_ones;

  (* anyconst *) logic [15:0] keys;
  (* anyconst *) logic [3:0] key_select;
  logic key_any;
  logic [3:0] key_first;
  logic key_selected;
  logic [15:0] key_sample;

  (* anyconst *) logic [3:0] io_addr;
  logic [7:0] io_rdata;

  (* anyconst *) logic [11:0] bus_addr;
  (* anyconst *) logic [7:0] mem_rdata;
  (* anyconst *) logic [7:0] io_rdata_in;
  logic bus_mem_sel;
  logic bus_io_sel;
  logic [7:0] bus_rdata;

  (* anyconst *) logic [5:0] fb_x;
  (* anyconst *) logic [4:0] fb_y;
  (* anyconst *) logic fb_draw_we;
  logic fb_old;
  logic fb_new;
  logic fb_collision;
  logic [2047:0] framebuffer;
  logic fb_scan_pixel;

  (* anyconst *) logic [7:0] sprite_byte;
  (* anyconst *) logic [2:0] sprite_bit;
  (* anyconst *) logic [5:0] sprite_base_x;
  (* anyconst *) logic [4:0] sprite_base_y;
  (* anyconst *) logic [3:0] sprite_row;
  logic sprite_on;
  logic [5:0] sprite_draw_x;
  logic [4:0] sprite_draw_y;

  (* anyseq *) logic timer_tick;
  (* anyseq *) logic timer_we;
  logic [7:0] delay_value;
  logic [7:0] sound_value;
  logic sound_active;

  (* anyseq *) logic loader_valid;
  (* anyseq *) logic [11:0] loader_offset;
  (* anyseq *) logic [7:0] loader_data_i;
  logic loader_we;
  logic [11:0] loader_addr;
  logic [7:0] loader_data_o;

  (* anyseq *) logic cpu_we;
  (* anyseq *) logic [11:0] cpu_addr;
  (* anyseq *) logic [7:0] cpu_data;
  logic arb_mem_we;
  logic [11:0] arb_mem_addr;
  logic [7:0] arb_mem_data;

  (* anyseq *) logic pc_we;
  (* anyseq *) logic [11:0] pc_next;
  logic [11:0] pc_out;

  (* anyseq *) logic rng_next;
  logic [7:0] rng_value;

  chip8_alu u_alu (.op_i(alu_op), .a_i(a), .b_i(b), .y_o(alu_y), .flag_o(
  alu_flag));
  chip8_decode u_decode (.opcode_i(opcode), .class_o(opcode_class), .x_o(
  x_idx), .y_o(y_idx), .n_o(n), .kk_o(kk), .nnn_o(nnn), .decoded_o(
    decoded));
  chip8_fetch u_fetch (.pc_i(pc), .mem_hi_i(a), .mem_lo_i(b), .raddr_hi_o(
  fetch_hi_addr), .raddr_lo_o(fetch_lo_addr), .opcode_o(fetched_opcode));
  chip8_datapath u_datapath (.draw_x_value_i(a[5:0]), .draw_y_value_i(b[4:0])
  , .v0_i(a), .nnn_i(nnn), .pc_i(pc), .pc_plus_2_o(pc_plus_2),
    .pc_plus_4_o(pc_plus_4), .jump_v0_o(jump_v0), .draw_x_o(dp_draw_x),
    .draw_y_o(dp_draw_y));
  chip8_skip_unit u_skip_unit (.opcode_class_i(opcode_class), .vx_i(a), .vy_i(b),
  .kk_i(kk), .n_i(n), .skip_o(skip_unit_skip));
  chip8_control u_control (.opcode_class_i(opcode_class), .kk_i(kk),
  .decoded_i(decoded), .is_draw_o(control_draw), .is_wait_key_o(
    control_wait_key), .is_timer_write_o(control_timer_write),
    .is_memory_burst_o(control_memory_burst), .uses_memory_o(
    control_uses_memory), .uses_display_o(control_uses_display),
      .uses_timer_o(control_uses_timer), .uses_keypad_o(
      control_uses_keypad), .legal_o(control_legal),
        .first_uop_o(control_first_uop));
  chip8_bcd u_bcd (.binary_i(a), .hundreds_o(bcd_hundreds), .tens_o(bcd_tens)
  , .ones_o(bcd_ones));
  chip8_keypad u_keypad (.keys_i(keys), .select_i(key_select),
  .selected_pressed_o(key_selected), .any_pressed_o(key_any),
    .first_pressed_o(key_first), .keys_o(key_sample));
  chip8_io_mux u_io_mux (.addr_i(io_addr), .delay_i(a), .sound_i(b), .keys_i(
  keys), .key_any_i(key_any), .key_first_i(key_first), .rdata_o(io_rdata))
    ;
  chip8_bus u_bus (.addr_i(bus_addr), .mem_rdata_i(mem_rdata), .io_rdata_i(
  io_rdata_in), .mem_sel_o(bus_mem_sel), .io_sel_o(bus_io_sel), .rdata_o(
    bus_rdata));
  chip8_framebuffer u_framebuffer (.clk_i(clk), .rst_ni(rst_n), .clear_i(
  1'b0), .draw_we_i(fb_draw_we), .draw_x_i(fb_x), .draw_y_i(fb_y),
    .scan_addr_i(11'd0), .old_pixel_o(fb_old), .new_pixel_o(fb_new),
    .scan_pixel_o(fb_scan_pixel), .framebuffer_o(framebuffer));
  chip8_collision_unit u_collision (.draw_we_i(fb_draw_we), .old_pixel_i(
  fb_old), .collision_o(fb_collision));
  chip8_sprite_blitter u_blitter (.sprite_byte_i(sprite_byte), .bit_i(
  sprite_bit), .base_x_i(sprite_base_x), .base_y_i(sprite_base_y), .row_i(
    sprite_row), .pixel_on_o(sprite_on), .draw_x_o(sprite_draw_x),
    .draw_y_o(sprite_draw_y));
  chip8_delay_timer u_delay_timer (.clk_i(clk), .rst_ni(rst_n), .tick_60hz_i(
  timer_tick), .we_i(timer_we), .wdata_i(a), .value_o(delay_value));
  chip8_sound_timer u_sound_timer (.clk_i(clk), .rst_ni(rst_n), .tick_60hz_i(
  timer_tick), .we_i(timer_we), .wdata_i(b), .value_o(sound_value),
    .active_o(sound_active));
  chip8_rom_loader u_loader (.clk_i(clk), .rst_ni(rst_n), .valid_i(
  loader_valid), .ready_o(), .offset_i(loader_offset), .data_i(
    loader_data_i), .mem_we_o(loader_we), .mem_addr_o(loader_addr),
    .mem_data_o(loader_data_o));
  chip8_mem_arbiter u_arbiter (.cpu_we_i(cpu_we), .cpu_addr_i(cpu_addr),
  .cpu_data_i(cpu_data), .loader_we_i(loader_we), .loader_addr_i(
    loader_addr), .loader_data_i(loader_data_o), .mem_we_o(arb_mem_we),
    .mem_addr_o(arb_mem_addr), .mem_data_o(arb_mem_data));
  chip8_pc u_pc (
  .clk_i(clk),
  .rst_ni(rst_n),
  .we_i(pc_we),
  .pc_d_i(pc_next),
  .pc_o(pc_out)
  );

  chip8_rng u_rng (
  .clk_i(clk),
  .rst_ni(rst_n),
  .advance_en_i(rng_next),
  .next_value_o(rng_value)
  );

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign alu_sum = {1'b0, a} + {1'b0, b};

  // ------------------------------------------------------------
  // Clocked testbench procedures
  // ------------------------------------------------------------

  always_ff @(posedge clk) begin
  past_valid <= '1;
  end

  /*
   * Formal reset discipline:
   * keep reset asserted for the initial formal step and release it
   afterwards.
   * This constrains rst_n before the DUT samples the first clock edge,
   avoiding
   * spurious X/undef counterexamples from uninitialized sequential state.
   */
  // ------------------------------------------------------------
  // Combinational checks
  // ------------------------------------------------------------

  always_comb begin
  if (!past_valid) begin
    assume (!rst_n);
  end
  end

  always_ff @(posedge clk) begin
  if (past_valid) begin
    assume (rst_n);
  end
  end

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
  assert (pc_plus_2 == ((pc + 12'd2) & FORMAL_ADDR_MASK));
  assert (pc_plus_4 == ((pc + 12'd4) & FORMAL_ADDR_MASK));
  assert (jump_v0 == ((nnn + {4'h0, a}) & FORMAL_ADDR_MASK));
  assert (dp_draw_x == a[5:0]);
  assert (dp_draw_y == b[4:0]);
  assert (skip_unit_skip == ((opcode_class == 4'h3 && a == kk) || (
    opcode_class == 4'h4 && a != kk) || (opcode_class == 4'h5 && n ==
    4'h0 && a == b) || (opcode_class == 4'h9 && n == 4'h0 && a != b)
      ));
  assert (control_draw == (opcode_class == 4'hd));
  assert (control_wait_key == (opcode_class == 4'hf && kk == 8'h0a));
  assert (control_timer_write == (opcode_class == 4'hf && (kk == 8'h15 ||
    kk == 8'h18)));
  assert (control_memory_burst == (opcode_class == 4'hf && (kk ==
    8'h55 || kk == 8'h65)));
  assert (({4'h0, bcd_hundreds} * 8'd100 + {4'h0, bcd_tens} * 8'd10 +
    {4'h0, bcd_ones}) == a);
  assert (bcd_hundreds <= 4'd2 && bcd_tens <= 4'd9 && bcd_ones <= 4'd9);
  assert (key_sample == keys);
  assert (key_selected == keys[key_select]);
  assert (key_any == (keys != 16'h0000));
  assert (fb_new == !fb_old);
  assert (fb_collision == (fb_draw_we & fb_old));
  assert (sprite_on == sprite_byte[7 - sprite_bit]);
  assert (sprite_draw_x == ((sprite_base_x + {3'b000, sprite_bit}) &
    FORMAL_SPRITE_X_MASK));
  assert (sprite_draw_y == ((sprite_base_y + {1'b0, sprite_row}) &
    FORMAL_SPRITE_Y_MASK));
  assert (bus_mem_sel == (bus_addr < FORMAL_IO_BASE));
  assert (bus_io_sel == (bus_addr >= FORMAL_IO_BASE));
  assert (bus_rdata == (bus_io_sel ? io_rdata_in : mem_rdata));
  assert (sound_active == (sound_value != 8'h00));
  assert (arb_mem_we == (loader_we | cpu_we));
  if (loader_we) begin
    assert (arb_mem_addr == loader_addr);
    assert (arb_mem_data == loader_data_o);
  end else begin
    assert (arb_mem_addr == cpu_addr);
    assert (arb_mem_data == cpu_data);
  end
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_MOV) assert (alu_y == b &&
    !alu_flag);
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_OR) assert (alu_y == (a | b) &&
    !alu_flag);
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_AND) assert (alu_y == (a & b) &&
    !alu_flag);
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_XOR) assert (alu_y == (a ^ b) &&
    !alu_flag);
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_ADD || alu_op ==
    chip8_alu_pkg::CHIP8_ALU_ADD_IMM) assert ({alu_flag, alu_y} ==
    alu_sum);
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_SUB) assert (alu_y == (a - b) &&
    alu_flag == (a >= b));
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_RSUB) assert (alu_y == (b - a)
    && alu_flag == (b >= a));
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_SHR) assert (alu_y == {1'b0,
    a[7:1]} && alu_flag == a[0]);
  if (alu_op == chip8_alu_pkg::CHIP8_ALU_SHL) assert (alu_y == {a[6:0],
    1'b0} && alu_flag == a[7]);
  end

  always_comb begin
  if (!rst_n) begin
    assert (pc_out == chip8_pkg::CHIP8_ROM_BASE);
    assert (delay_value == 8'h00);
    assert (sound_value == 8'h00);
  end
  end

  always_ff @(posedge clk) begin
  if (past_valid && rst_n) begin
    assert (pc_out <= FORMAL_ADDR_MASK);
    assert (sound_active == (sound_value != 8'h00));
  end
  end
endmodule

`default_nettype wire

// EOF

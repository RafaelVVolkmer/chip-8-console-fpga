// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tb_chip8_blocks_exhaustive.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Tb chip8 blocks exhaustive.
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

module tb_chip8_blocks_exhaustive;
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
  logic [7:0] fetch_hi;
  logic [7:0] fetch_lo;
  logic [11:0] fetch_hi_addr;
  logic [11:0] fetch_lo_addr;
  logic [15:0] fetched_opcode;

  logic [5:0] draw_x_in;
  logic [4:0] draw_y_in;
  logic [7:0] v0;
  logic [11:0] pc_plus_2;
  logic [11:0] pc_plus_4;
  logic [11:0] jump_v0;
  logic [5:0] dp_draw_x;
  logic [4:0] dp_draw_y;

  logic [3:0] exec_class;
  logic [7:0] exec_vx;
  logic [7:0] exec_vy;
  logic [7:0] exec_kk;
  logic [3:0] exec_n;
  logic exec_skip;

  logic [3:0] control_class;
  logic [7:0] control_kk;
  logic control_draw;
  logic control_wait_key;
  logic control_timer_write;
  logic control_memory_burst;
  chip8_core_pkg::chip8_decoded_t control_decoded;
  logic control_uses_memory;
  logic control_uses_display;
  logic control_uses_timer;
  logic control_uses_keypad;
  logic control_legal;
  chip8_core_pkg::chip8_uop_t control_first_uop;

  logic [7:0] bcd_in;
  logic [3:0] bcd_hundreds;
  logic [3:0] bcd_tens;
  logic [3:0] bcd_ones;

  logic [15:0] keys;
  logic [3:0] key_select;
  logic key_selected;
  logic key_any;
  logic [3:0] key_first;
  logic [15:0] key_sample;
  logic [15:0] keys_sync_in;
  logic [15:0] keys_sync_out;
  logic [15:0] keys_debounce_out;

  logic [3:0] io_addr;
  logic [7:0] io_delay;
  logic [7:0] io_sound;
  logic [7:0] io_rdata;

  logic [11:0] bus_addr;
  logic [7:0] bus_mem_rdata;
  logic [7:0] bus_io_rdata;
  logic bus_mem_sel;
  logic bus_io_sel;
  logic [7:0] bus_rdata;

  logic [11:0] addr_decode_addr;
  logic addr_mem_sel;
  logic addr_io_sel;

  logic pc_we;
  logic [11:0] pc_next;
  logic [11:0] pc_out;

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

  logic stack_push;
  logic stack_pop;
  logic [11:0] stack_push_data;
  logic [11:0] stack_pop_data;
  logic stack_overflow;
  logic stack_underflow;

  logic rng_next;
  logic [7:0] rng_value;

  logic trace_valid_i;
  logic [11:0] trace_pc_i;
  logic [15:0] trace_opcode_i;
  logic trace_valid_o;
  logic [11:0] trace_pc_o;
  logic [15:0] trace_opcode_o;

  logic breakpoint_enable;
  logic [11:0] breakpoint_pc;
  logic [11:0] breakpoint_match_pc;
  logic breakpoint_hit;

  logic [11:0] dbg_pc_i;
  logic [15:0] dbg_opcode_i;
  logic [11:0] dbg_pc_o;
  logic [15:0] dbg_opcode_o;
  chip8_core_pkg::chip8_state_t dbg_state_i;
  chip8_core_pkg::chip8_state_t dbg_state_o;
  chip8_core_pkg::chip8_decoded_t dbg_decoded_i;
  logic dbg_halted_i;
  logic dbg_fault_illegal_i;
  logic [31:0] dbg_status_o;
  logic [31:0] dbg_scb_hfsr_o;
  logic [31:0] dbg_scb_cfsr_o;
  logic [31:0] dbg_scb_mmfar_o;
  logic [31:0] dbg_scb_bfar_o;
  logic [31:0] dbg_scb_shcsr_o;
  logic [31:0] dbg_scb_dfsr_o;
  logic [31:0] dbg_scb_afsr_o;
  logic instr_trace_valid_o;
  logic [27:0] instr_trace_word;

  logic timer_tick;
  logic delay_we;
  logic sound_we;
  logic [7:0] delay_wdata;
  logic [7:0] sound_wdata;
  logic [7:0] delay_value;
  logic [7:0] sound_value;
  logic sound_active;
  logic fast_tick;
  logic timer_rst_n;
  logic full_delay_we;
  logic full_sound_we;
  logic [7:0] full_delay_value;
  logic [7:0] full_sound_value;
  logic full_sound_active;

  logic fb_clear;
  logic fb_draw_we;
  logic [5:0] fb_x;
  logic [4:0] fb_y;
  logic fb_old;
  logic fb_new;
  logic [2047:0] framebuffer;
  logic fb_scan_pixel;
  logic fb_collision;
  logic dc_old;
  logic dc_new;
  logic [2047:0] dc_framebuffer;
  logic dc_scan_pixel;

  logic [7:0] sprite_byte;
  logic [2:0] sprite_bit;
  logic [5:0] sprite_base_x;
  logic [4:0] sprite_base_y;
  logic [3:0] sprite_row;
  logic sprite_pixel_on;
  logic [5:0] sprite_draw_x;
  logic [4:0] sprite_draw_y;

  logic scan_valid;
  logic [5:0] scan_x;
  logic [4:0] scan_y;
  logic scan_pixel;

  logic ram_we;
  logic [11:0] ram_raddr0;
  logic [11:0] ram_raddr1;
  logic [11:0] ram_waddr;
  logic [7:0] ram_wdata;
  logic [7:0] ram_rdata0;
  logic [7:0] ram_rdata1;

  logic [11:0] mem_raddr0;
  logic [11:0] mem_raddr1;
  logic mem_we;
  logic [11:0] mem_waddr;
  logic [7:0] mem_wdata;
  logic [7:0] mem_rdata0;
  logic [7:0] mem_rdata1;

  logic [6:0] font_addr;
  logic [7:0] font_data;
  logic [11:0] map_addr;
  logic map_is_font;
  logic map_is_program;

  logic loader_valid;
  logic [11:0] loader_offset;
  logic [7:0] loader_data_i;
  logic loader_we;
  logic [11:0] loader_addr;
  logic [7:0] loader_data_o;

  logic arb_cpu_we;
  logic [11:0] arb_cpu_addr;
  logic [7:0] arb_cpu_data;
  logic arb_loader_we;
  logic [11:0] arb_loader_addr;
  logic [7:0] arb_loader_data;
  logic arb_mem_we;
  logic [11:0] arb_mem_addr;
  logic [7:0] arb_mem_data;

  // ------------------------------------------------------------
  // Combinational checks
  // ------------------------------------------------------------

  always_comb begin
  control_decoded = '{
    opcode: {control_class, 4'h0, control_kk},
    opcode_class: control_class,
    x: 4'h0,
    y: control_kk[7:4],
    n: control_kk[3:0],
    kk: control_kk,
    nnn: {4'h0, control_kk},
    op: chip8_core_pkg::OP_ILLEGAL,
    first_uop: chip8_core_pkg::UOP_TRAP,
    legal: 1'b0,
    writes_vx: 1'b0,
    writes_vf: 1'b0,
    uses_memory: 1'b0,
    uses_display: control_class == 4'hd,
    uses_timer: control_class == 4'hf &&
    ((control_kk == 8'h07) | (control_kk == 8'h15) |
      (control_kk == 8'h18)),
    uses_keypad: control_class == 4'hf && control_kk == 8'h0a
  };

  if (control_class == 4'hd) begin
    control_decoded.op = chip8_core_pkg::OP_DRAW;
    control_decoded.first_uop = chip8_core_pkg::UOP_DRAW_PIXEL;
    control_decoded.legal = '1;
  end else if (control_class == 4'hf && control_kk == 8'h0a) begin
    control_decoded.op = chip8_core_pkg::OP_WAIT_KEY;
    control_decoded.first_uop = chip8_core_pkg::UOP_WAIT_KEY;
    control_decoded.legal = '1;
  end else if (control_class == 4'hf &&
    ((control_kk == 8'h15) | (control_kk == 8'h18))) begin
    control_decoded.op = (control_kk == 8'h15) ?
    chip8_core_pkg::OP_TIMER_DELAY_WRITE :
      chip8_core_pkg::OP_TIMER_SOUND_WRITE;
    control_decoded.first_uop = chip8_core_pkg::UOP_EXEC;
    control_decoded.legal = '1;
  end else if (control_class == 4'hf &&
    ((control_kk == 8'h55) | (control_kk == 8'h65))) begin
    control_decoded.op = (control_kk == 8'h55) ?
    chip8_core_pkg::OP_STORE_REGS :
      chip8_core_pkg::OP_LOAD_REGS;
    control_decoded.first_uop = (control_kk == 8'h55) ?
    chip8_core_pkg::UOP_MEM_WRITE :
      chip8_core_pkg::UOP_MEM_READ;
    control_decoded.legal = '1;
    control_decoded.uses_memory = '1;
  end
  end

  chip8_alu u_alu (.op_i(alu_op), .a_i(alu_a), .b_i(alu_b), .y_o(alu_y),
  .flag_o(alu_flag));
  chip8_decode u_decode (.opcode_i(opcode), .class_o(opcode_class), .x_o(
  x_idx), .y_o(y_idx), .n_o(n), .kk_o(kk), .nnn_o(nnn), .decoded_o(
    decoded));
  chip8_fetch u_fetch (.pc_i(pc_in), .mem_hi_i(fetch_hi), .mem_lo_i(fetch_lo)
  , .raddr_hi_o(fetch_hi_addr), .raddr_lo_o(fetch_lo_addr), .opcode_o(
    fetched_opcode));
  chip8_datapath u_datapath (.draw_x_value_i(draw_x_in), .draw_y_value_i(
  draw_y_in), .v0_i(v0), .nnn_i(nnn), .pc_i(pc_in), .pc_plus_2_o(
    pc_plus_2), .pc_plus_4_o(pc_plus_4), .jump_v0_o(jump_v0), .draw_x_o(
    dp_draw_x), .draw_y_o(dp_draw_y));
  chip8_skip_unit u_skip_unit (.opcode_class_i(exec_class), .vx_i(exec_vx), .vy_i(
  exec_vy), .kk_i(exec_kk), .n_i(exec_n), .skip_o(exec_skip));
  chip8_control u_control (.opcode_class_i(control_class), .kk_i(control_kk),
  .decoded_i(control_decoded), .is_draw_o(control_draw), .is_wait_key_o(
    control_wait_key), .is_timer_write_o(control_timer_write),
    .is_memory_burst_o(control_memory_burst), .uses_memory_o(
    control_uses_memory), .uses_display_o(control_uses_display),
      .uses_timer_o(control_uses_timer), .uses_keypad_o(
      control_uses_keypad), .legal_o(control_legal),
        .first_uop_o(control_first_uop));
  chip8_bcd u_bcd (.binary_i(bcd_in), .hundreds_o(bcd_hundreds), .tens_o(
  bcd_tens), .ones_o(bcd_ones));
  chip8_keypad u_keypad (.keys_i(keys), .select_i(key_select),
  .selected_pressed_o(key_selected), .any_pressed_o(key_any),
    .first_pressed_o(key_first), .keys_o(key_sample));
  chip8_key_sync u_key_sync (.clk_i(clk), .rst_ni(rst_n), .keys_async_i(
  keys_sync_in), .keys_sync_o(keys_sync_out));
  chip8_key_debounce u_key_debounce (.clk_i(clk), .rst_ni(rst_n), .keys_i(
  keys_sync_out), .keys_o(keys_debounce_out));
  chip8_io_mux u_io_mux (.addr_i(io_addr), .delay_i(io_delay), .sound_i(
  io_sound), .keys_i(keys), .key_any_i(key_any), .key_first_i(key_first),
    .rdata_o(io_rdata));
  chip8_addr_decode u_addr_decode (.addr_i(addr_decode_addr), .mem_sel_o(
  addr_mem_sel), .io_sel_o(addr_io_sel));
  chip8_bus u_bus (.addr_i(bus_addr), .mem_rdata_i(bus_mem_rdata),
  .io_rdata_i(bus_io_rdata), .mem_sel_o(bus_mem_sel), .io_sel_o(
    bus_io_sel), .rdata_o(bus_rdata));
  chip8_pc u_pc (.clk_i(clk), .rst_ni(rst_n), .we_i(pc_we), .pc_d_i(pc_next)
  , .pc_o(pc_out));
  chip8_regfile u_regfile (.clk_i(clk), .rst_ni(rst_n), .x_addr_i(reg_x_addr)
  , .y_addr_i(reg_y_addr), .dbg_addr_i(reg_dbg_addr), .we_i(reg_we),
    .waddr_i(reg_waddr), .wdata_i(reg_wdata), .x_data_o(reg_x_data),
    .y_data_o(reg_y_data), .dbg_data_o(reg_dbg_data), .v0_data_o(
      reg_v0_data), .vf_data_o(reg_vf_data));
  chip8_stack u_stack (.clk_i(clk), .rst_ni(rst_n), .push_we_i(stack_push),
  .pop_we_i(stack_pop), .push_data_i(stack_push_data), .pop_data_o(
    stack_pop_data), .overflow_o(stack_overflow), .underflow_o(
    stack_underflow));
  chip8_rng u_rng (.clk_i(clk), .rst_ni(rst_n), .advance_en_i(rng_next),
  .next_value_o(rng_value));
  chip8_trace u_trace (.clk_i(clk), .rst_ni(rst_n), .valid_i(trace_valid_i),
  .pc_i(trace_pc_i), .opcode_i(trace_opcode_i), .valid_o(trace_valid_o),
    .pc_o(trace_pc_o), .opcode_o(trace_opcode_o));
  chip8_breakpoint u_breakpoint (.enable_i(breakpoint_enable), .pc_i(
  breakpoint_pc), .break_pc_i(breakpoint_match_pc), .hit_o(breakpoint_hit)
    );
  chip8_debug_regs u_debug_regs (.clk_i(clk), .rst_ni(rst_n), .pc_i(dbg_pc_i)
  , .opcode_i(dbg_opcode_i), .state_i(dbg_state_i), .decoded_i(
    dbg_decoded_i), .halted_i(dbg_halted_i), .fault_illegal_i(
    dbg_fault_illegal_i), .pc_o(dbg_pc_o), .opcode_o(dbg_opcode_o),
      .state_o(dbg_state_o), .status_o(dbg_status_o),
      .scb_hfsr_o(dbg_scb_hfsr_o), .scb_cfsr_o(
        dbg_scb_cfsr_o), .scb_mmfar_o(dbg_scb_mmfar_o),
        .scb_bfar_o(dbg_scb_bfar_o), .scb_shcsr_o(
          dbg_scb_shcsr_o), .scb_dfsr_o(
          dbg_scb_dfsr_o), .scb_afsr_o(
            dbg_scb_afsr_o));
  chip8_instruction_trace u_instruction_trace (.clk_i(clk), .rst_ni(rst_n),
  .valid_i(trace_valid_i), .pc_i(trace_pc_i), .opcode_i(trace_opcode_i),
    .valid_o(instr_trace_valid_o), .trace_word_o(instr_trace_word));
  chip8_delay_timer u_delay_timer (.clk_i(clk), .rst_ni(rst_n), .tick_60hz_i(
  timer_tick), .we_i(delay_we), .wdata_i(delay_wdata), .value_o(
    delay_value));
  chip8_sound_timer u_sound_timer (.clk_i(clk), .rst_ni(rst_n), .tick_60hz_i(
  timer_tick), .we_i(sound_we), .wdata_i(sound_wdata), .value_o(
    sound_value), .active_o(sound_active));
  chip8_timer_60hz #(.CLK_HZ(6), .TICK_HZ(2)) u_fast_timer (.clk_i(clk),
  .rst_ni(timer_rst_n), .tick_o(fast_tick));
  chip8_timer #(.CLK_HZ(6), .TICK_HZ(2)) u_full_timer (.clk_i(clk), .rst_ni(
  timer_rst_n), .delay_we_i(full_delay_we), .sound_we_i(full_sound_we),
    .delay_wdata_i(delay_wdata), .sound_wdata_i(sound_wdata), .delay_o(
    full_delay_value), .sound_o(full_sound_value), .sound_active_o(
      full_sound_active));
  chip8_framebuffer u_framebuffer (.clk_i(clk), .rst_ni(rst_n), .clear_i(
  fb_clear), .draw_we_i(fb_draw_we), .draw_x_i(fb_x), .draw_y_i(fb_y),
    .scan_addr_i(11'd0), .old_pixel_o(fb_old), .new_pixel_o(fb_new),
    .scan_pixel_o(fb_scan_pixel), .framebuffer_o(framebuffer));
  chip8_collision_unit u_collision (.draw_we_i(fb_draw_we), .old_pixel_i(
  fb_old), .collision_o(fb_collision));
  chip8_display_controller u_display_controller (.clk_i(clk), .rst_ni(rst_n)
  , .clear_i(fb_clear), .draw_we_i(fb_draw_we), .draw_x_i(fb_x),
    .draw_y_i(fb_y), .scan_addr_i(11'd0), .old_pixel_o(dc_old),
    .new_pixel_o(dc_new), .scan_pixel_o(dc_scan_pixel),
      .framebuffer_o(dc_framebuffer));
  chip8_sprite_blitter u_blitter (.sprite_byte_i(sprite_byte), .bit_i(
  sprite_bit), .base_x_i(sprite_base_x), .base_y_i(sprite_base_y), .row_i(
    sprite_row), .pixel_on_o(sprite_pixel_on), .draw_x_o(sprite_draw_x)
    , .draw_y_o(sprite_draw_y));
  chip8_video_scanout u_scanout (.clk_i(clk), .rst_ni(rst_n), .framebuffer_i(
  framebuffer), .valid_o(scan_valid), .x_o(scan_x), .y_o(scan_y),
    .pixel_o(scan_pixel));
  chip8_ram u_ram (.clk_i(clk), .raddr0_i(ram_raddr0), .raddr1_i(ram_raddr1),
  .we_i(ram_we), .waddr_i(ram_waddr), .wdata_i(ram_wdata), .rdata0_o(
    ram_rdata0), .rdata1_o(ram_rdata1));
  chip8_memory u_memory (.clk_i(clk), .rst_ni(rst_n), .raddr0_i(mem_raddr0),
  .raddr1_i(mem_raddr1), .we_i(mem_we), .waddr_i(mem_waddr), .wdata_i(
    mem_wdata), .rdata0_o(mem_rdata0), .rdata1_o(mem_rdata1));
  chip8_font_rom u_font (.addr_i(font_addr), .data_o(font_data));
  chip8_memory_map u_memory_map (.addr_i(map_addr), .is_font_o(map_is_font),
  .is_program_o(map_is_program));
  chip8_rom_loader u_loader (.clk_i(clk), .rst_ni(rst_n), .valid_i(
  loader_valid), .ready_o(), .offset_i(loader_offset), .data_i(
    loader_data_i), .mem_we_o(loader_we), .mem_addr_o(loader_addr),
    .mem_data_o(loader_data_o));
  chip8_mem_arbiter u_arbiter (.cpu_we_i(arb_cpu_we), .cpu_addr_i(
  arb_cpu_addr), .cpu_data_i(arb_cpu_data), .loader_we_i(arb_loader_we),
    .loader_addr_i(arb_loader_addr), .loader_data_i(arb_loader_data),
    .mem_we_o(arb_mem_we), .mem_addr_o(arb_mem_addr), .mem_data_o(
      arb_mem_data));

  // ------------------------------------------------------------
  // Stimulus and checks
  // ------------------------------------------------------------

  always #5 clk <= !clk;

  // ------------------------------------------------------------
  // Testbench tasks
  // ------------------------------------------------------------

  function automatic logic [7:0] rng_step(input logic [7:0] value);
  rng_step = {value[6:0], value[7] ^ value[5] ^ value[4] ^ value[3]};
  endfunction

  function automatic logic [3:0] first_pressed_model(input logic [15:0] value)
  ;
  logic [15:0] first_onehot;
  begin
    first_onehot = value & (~value + 1'b1);
    first_pressed_model[0] = |(first_onehot & 16'haaaa);
    first_pressed_model[1] = |(first_onehot & 16'hcccc);
    first_pressed_model[2] = |(first_onehot & 16'hf0f0);
    first_pressed_model[3] = |(first_onehot & 16'hff00);
  end
  endfunction

  task automatic tick;
  begin
    @(posedge clk);
    #1;
  end
  endtask

  task automatic reset_dut;
  begin
    rst_n = '0;
    repeat (3) tick();
    rst_n = '1;
    tick();
  end
  endtask

  task automatic expect_alu(input chip8_alu_pkg::chip8_alu_op_t op,
  input logic [7:0] a, input logic [7:0] b);
  logic [8:0] sum;
  logic [7:0] expected_y;
  logic expected_flag;
  begin
    alu_op = op;
    alu_a = a;
    alu_b = b;
    sum = {1'b0, a} + {1'b0, b};
    expected_y = a;
    expected_flag = '0;
    unique case (op)
    chip8_alu_pkg::CHIP8_ALU_MOV: expected_y = b;
    chip8_alu_pkg::CHIP8_ALU_OR: expected_y = a | b;
    chip8_alu_pkg::CHIP8_ALU_AND: expected_y = a & b;
    chip8_alu_pkg::CHIP8_ALU_XOR: expected_y = a ^ b;
    chip8_alu_pkg::CHIP8_ALU_ADD,
    chip8_alu_pkg::CHIP8_ALU_ADD_IMM: begin expected_y =
      sum[7:0]; expected_flag = sum[8]; end
    chip8_alu_pkg::CHIP8_ALU_SUB: begin expected_y =
      a - b; expected_flag = a >= b; end
    chip8_alu_pkg::CHIP8_ALU_SHR: begin expected_y = {1'b0,
      a[7:1]}; expected_flag = a[0]; end
    chip8_alu_pkg::CHIP8_ALU_RSUB: begin expected_y =
      b - a; expected_flag = b >= a; end
    chip8_alu_pkg::CHIP8_ALU_SHL: begin expected_y = {a[6:0],
      1'b0}; expected_flag = a[7]; end
    default: begin expected_y = a; expected_flag = '0; end
    endcase
    #1;
    assert (alu_y == expected_y) else $fatal(1,
    "ALU y op=%0d a=%02h b=%02h got=%02h exp=%02h", op, a, b,
      alu_y, expected_y);
    assert (alu_flag == expected_flag) else $fatal(1,
    "ALU flag op=%0d a=%02h b=%02h got=%0b exp=%0b", op, a, b,
      alu_flag, expected_flag);
  end
  endtask

  initial begin
  int idx;
  int jdx;
  int op_idx;
  logic [7:0] rng_model;

  clk = '0;
  rst_n = '0;
  alu_op = chip8_alu_pkg::CHIP8_ALU_MOV;
  alu_a = '0;
  alu_b = '0;
  opcode = '0;
  pc_in = '0;
  fetch_hi = '0;
  fetch_lo = '0;
  draw_x_in = '0;
  draw_y_in = '0;
  v0 = '0;
  exec_class = '0;
  exec_vx = '0;
  exec_vy = '0;
  exec_kk = '0;
  exec_n = '0;
  control_class = '0;
  control_kk = '0;
  bcd_in = '0;
  keys = '0;
  key_select = '0;
  keys_sync_in = '0;
  io_addr = '0;
  io_delay = 8'h12;
  io_sound = 8'h34;
  bus_addr = '0;
  bus_mem_rdata = 8'hAA;
  bus_io_rdata = 8'h55;
  addr_decode_addr = '0;
  pc_we = '0;
  pc_next = '0;
  reg_we = '0;
  reg_x_addr = '0;
  reg_y_addr = '0;
  reg_dbg_addr = '0;
  reg_waddr = '0;
  reg_wdata = '0;
  stack_push = '0;
  stack_pop = '0;
  stack_push_data = '0;
  rng_next = '0;
  trace_valid_i = '0;
  trace_pc_i = '0;
  trace_opcode_i = '0;
  breakpoint_enable = '0;
  breakpoint_pc = '0;
  breakpoint_match_pc = '0;
  dbg_pc_i = '0;
  dbg_opcode_i = '0;
  dbg_state_i = chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC;
  dbg_decoded_i = '0;
  dbg_halted_i = '0;
  dbg_fault_illegal_i = '0;
  timer_tick = '0;
  delay_we = '0;
  sound_we = '0;
  delay_wdata = '0;
  sound_wdata = '0;
  timer_rst_n = '0;
  full_delay_we = '0;
  full_sound_we = '0;
  fb_clear = '0;
  fb_draw_we = '0;
  fb_x = '0;
  fb_y = '0;
  sprite_byte = '0;
  sprite_bit = '0;
  sprite_base_x = '0;
  sprite_base_y = '0;
  sprite_row = '0;
  ram_we = '0;
  ram_raddr0 = '0;
  ram_raddr1 = '0;
  ram_waddr = '0;
  ram_wdata = '0;
  mem_we = '0;
  mem_raddr0 = '0;
  mem_raddr1 = 12'h001;
  mem_waddr = '0;
  mem_wdata = '0;
  font_addr = '0;
  map_addr = '0;
  loader_valid = '0;
  loader_offset = '0;
  loader_data_i = '0;
  arb_cpu_we = '0;
  arb_cpu_addr = '0;
  arb_cpu_data = '0;
  arb_loader_we = '0;
  arb_loader_addr = '0;
  arb_loader_data = '0;

  reset_dut();

  for (op_idx = '0; op_idx < 10; op_idx++) begin
    for (idx = '0; idx < 256; idx++) begin
    for (jdx = '0; jdx < 256; jdx++) begin
      expect_alu(chip8_alu_pkg::chip8_alu_op_t'(op_idx[3:0]), 8'(
      idx), 8'(jdx));
    end
    end
  end

  for (idx = '0; idx < 65536; idx++) begin
    opcode = 16'(idx);
    #1;
    assert (opcode_class == opcode[15:12]);
    assert (x_idx == opcode[11:8]);
    assert (y_idx == opcode[7:4]);
    assert (n == opcode[3:0]);
    assert (kk == opcode[7:0]);
    assert (nnn == opcode[11:0]);
  end

  fetch_hi = 8'hca;
  fetch_lo = 8'hfe;
  for (idx = '0; idx < 4096; idx++) begin
    pc_in = 12'(idx);
    #1;
    assert (fetch_hi_addr == pc_in);
    assert (fetch_lo_addr == ((pc_in + 1'b1) & 12'hfff));
    assert (fetched_opcode == 16'hcafe);
    assert (pc_plus_2 == ((pc_in + 12'd2) & 12'hfff));
    assert (pc_plus_4 == ((pc_in + 12'd4) & 12'hfff));
  end

  nnn = 12'hf80;
  for (idx = '0; idx < 256; idx++) begin
    v0 = 8'(idx);
    draw_x_in = 6'(idx);
    draw_y_in = 5'(idx);
    #1;
    assert (jump_v0 == ((nnn + {4'h0, v0}) & 12'hfff));
    assert (dp_draw_x == draw_x_in);
    assert (dp_draw_y == draw_y_in);
  end

  for (idx = '0; idx < 16; idx++) begin
    control_class = 4'(idx);
    for (jdx = '0; jdx < 256; jdx++) begin
    control_kk = 8'(jdx);
    #1;
    assert (control_draw == (control_class == 4'hd));
    assert (control_wait_key == (control_class == 4'hf &&
      control_kk == 8'h0a));
    assert (control_timer_write == (control_class == 4'hf && (
      control_kk == 8'h15 || control_kk == 8'h18)));
    assert (control_memory_burst == (control_class == 4'hf && (
      control_kk == 8'h55 || control_kk == 8'h65)));
    end
  end

  for (idx = '0; idx < 16; idx++) begin
    exec_class = 4'(idx);
    for (jdx = '0; jdx < 16; jdx++) begin
    exec_n = 4'(jdx);
    exec_vx = 8'(jdx);
    exec_vy = 8'(idx);
    exec_kk = 8'(idx);
    #1;
    assert (exec_skip == ((exec_class == 4'h3 && exec_vx == exec_kk)
      || (exec_class == 4'h4 && exec_vx != exec_kk) || (
      exec_class == 4'h5 && exec_n == 4'h0 && exec_vx ==
        exec_vy) || (exec_class == 4'h9 && exec_n ==
        4'h0 && exec_vx != exec_vy)));
    end
  end

  for (idx = '0; idx < 256; idx++) begin
    bcd_in = 8'(idx);
    #1;
    assert (bcd_hundreds == 4'((idx / 100) % 10));
    assert (bcd_tens == 4'((idx / 10) % 10));
    assert (bcd_ones == 4'(idx % 10));
  end

  for (idx = '0; idx < 65536; idx++) begin
    keys = 16'(idx);
    key_select = 4'(idx);
    #1;
    assert (key_sample == keys);
    assert (key_any == (keys != 16'h0000));
    assert (key_selected == keys[key_select]);
    assert (key_first == first_pressed_model(keys));
  end

  keys_sync_in = 16'ha55a;
  tick();
  keys_sync_in = 16'hf00f;
  tick();
  assert (keys_sync_out == 16'ha55a);
  assert (keys_debounce_out == 16'h0000);
  tick();
  assert (keys_sync_out == 16'hf00f);
  assert (keys_debounce_out == 16'h0000);
  tick();
  assert (keys_debounce_out == (16'ha55a & 16'hf00f));

  keys = 16'hc35a;
  io_delay = 8'hde;
  io_sound = 8'had;
  for (idx = '0; idx < 16; idx++) begin
    io_addr = 4'(idx);
    #1;
    unique case (io_addr)
    chip8_periph_pkg::CHIP8_IO_DELAY: assert (io_rdata == io_delay);
    chip8_periph_pkg::CHIP8_IO_SOUND: assert (io_rdata == io_sound);
    chip8_periph_pkg::CHIP8_IO_KEYS_LO: assert (io_rdata ==
      keys[7:0]);
    chip8_periph_pkg::CHIP8_IO_KEYS_HI: assert (io_rdata ==
      keys[15:8]);
    chip8_periph_pkg::CHIP8_IO_KEY_ANY: assert (io_rdata == {7'h00,
      key_any});
    chip8_periph_pkg::CHIP8_IO_KEY_FIRST: assert (io_rdata ==
      {4'h0, key_first});
    default: assert (io_rdata == 8'h00);
    endcase
  end

  for (idx = '0; idx < 4096; idx++) begin
    addr_decode_addr = 12'(idx);
    bus_addr = 12'(idx);
    bus_mem_rdata = 8'(idx);
    bus_io_rdata = ~8'(idx);
    #1;
    assert (addr_mem_sel == (addr_decode_addr < 12'hff0));
    assert (addr_io_sel == (addr_decode_addr >= 12'hff0));
    assert (bus_mem_sel == (bus_addr < 12'hff0));
    assert (bus_io_sel == (bus_addr >= 12'hff0));
    assert (bus_rdata == (bus_io_sel ? bus_io_rdata : bus_mem_rdata));
  end

  assert (pc_out == chip8_pkg::CHIP8_ROM_BASE);
  pc_we = '1;
  for (idx = '0; idx < 64; idx++) begin
    pc_next = (12'hff0 + 12'(idx)) & 12'hfff;
    tick();
    assert (pc_out == pc_next);
  end
  pc_we = '0;
  pc_next = 12'h123;
  tick();
  assert (pc_out != 12'h123);

  reg_we = '1;
  for (idx = '0; idx < 16; idx++) begin
    reg_waddr = 4'(idx);
    reg_wdata = 8'(8'h80 + 8'(idx));
    tick();
  end
  reg_we = '0;
  for (idx = '0; idx < 16; idx++) begin
    reg_x_addr = 4'(idx);
    reg_y_addr = 4'(15 - idx);
    reg_dbg_addr = 4'(idx);
    #1;
    assert (reg_x_data == 8'(8'h80 + 8'(idx)));
    assert (reg_dbg_data == 8'(8'h80 + 8'(idx)));
    assert (reg_y_data == 8'(8'h80 + 8'(15 - idx)));
  end
  assert (reg_v0_data == 8'h80);
  assert (reg_vf_data == 8'h8f);

  stack_push = '1;
  stack_pop = '0;
  for (idx = '0; idx < 16; idx++) begin
    stack_push_data = (12'h300 + 12'(idx)) & 12'hfff;
    tick();
    assert (!stack_overflow && !stack_underflow);
  end
  stack_push = '0;
  for (idx = 15; idx >= 0; idx--) begin
    #1 assert (stack_pop_data == ((12'h300 + 12'(idx)) & 12'hfff));
    stack_pop = '1;
    tick();
    assert (!stack_overflow && !stack_underflow);
    stack_pop = '0;
  end

  rng_model = 8'ha5;
  rng_next = '0;
  repeat (3) begin
    #1 assert (rng_value == rng_step(rng_model));
    tick();
  end
  rng_next = '1;
  repeat (8) begin
    #1 assert (rng_value == rng_step(rng_model));
    tick();
    rng_model = rng_step(rng_model);
  end

  trace_valid_i = '1;
  trace_pc_i = 12'habc;
  trace_opcode_i = 16'hdeaf;
  dbg_pc_i = 12'h135;
  dbg_opcode_i = 16'h2468;
  dbg_state_i = chip8_core_pkg::CHIP8_CORE_PKG_STATE_DRAW;
  dbg_decoded_i = decoded;
  dbg_halted_i = '1;
  dbg_fault_illegal_i = '1;
  tick();
  dbg_fault_illegal_i = '0;
  assert (trace_valid_o && trace_pc_o == 12'habc && trace_opcode_o ==
    16'hdeaf);
  assert (instr_trace_valid_o && instr_trace_word == {12'habc, 16'hdeaf});
  assert (dbg_pc_o == 12'h135 && dbg_opcode_o == 16'h2468);
  assert (dbg_state_o == chip8_core_pkg::CHIP8_CORE_PKG_STATE_DRAW);
  assert (dbg_status_o[15]);
  assert (dbg_scb_hfsr_o[30]);
  assert (dbg_scb_cfsr_o[16]);
  assert (dbg_scb_shcsr_o[18]);
  assert (dbg_scb_dfsr_o[0]);
  assert (dbg_scb_afsr_o[0]);
  assert (dbg_scb_mmfar_o == 32'h00000000);
  assert (dbg_scb_bfar_o == 32'h00000000);
  trace_valid_i = '0;
  trace_pc_i = 12'h111;
  trace_opcode_i = 16'h2222;
  tick();
  assert (!trace_valid_o && trace_pc_o == 12'habc && trace_opcode_o ==
    16'hdeaf);
  breakpoint_enable = '1;
  breakpoint_pc = 12'h444;
  breakpoint_match_pc = 12'h444;
  #1 assert (breakpoint_hit);
  breakpoint_match_pc = 12'h445;
  #1 assert (!breakpoint_hit);
  breakpoint_enable = '0;
  #1 assert (!breakpoint_hit);

  delay_wdata = 8'h03;
  sound_wdata = 8'h02;
  delay_we = '1;
  sound_we = '1;
  tick();
  delay_we = '0;
  sound_we = '0;
  assert (delay_value == 8'h03 && sound_value == 8'h02 && sound_active);
  timer_tick = '1;
  tick();
  assert (delay_value == 8'h02 && sound_value == 8'h01 && sound_active);
  tick();
  assert (delay_value == 8'h01 && sound_value == 8'h00 && !sound_active);
  tick();
  assert (delay_value == 8'h00 && sound_value == 8'h00 && !sound_active);
  timer_tick = '0;

  timer_rst_n = '0;
  tick();
  timer_rst_n = '1;
  tick();
  assert (!fast_tick);
  tick();
  assert (!fast_tick);
  tick();
  assert (fast_tick);
  tick();
  assert (!fast_tick);
  full_delay_we = '1;
  full_sound_we = '1;
  delay_wdata = 8'h02;
  sound_wdata = 8'h02;
  tick();
  full_delay_we = '0;
  full_sound_we = '0;
  repeat (3) tick();
  assert (full_delay_value <= 8'h02 && full_sound_value <= 8'h02);
  assert (full_sound_active == (full_sound_value != 8'h00));

  fb_clear = '1;
  tick();
  fb_clear = '0;
  assert (framebuffer == '0);
  assert (dc_framebuffer == '0);
  for (idx = '0; idx < 2048; idx++) begin
    fb_x = 6'(idx);
    fb_y = 5'(idx >> 6);
    #1;
    assert (!fb_old && fb_new && !fb_collision);
    fb_draw_we = '1;
    tick();
    assert (framebuffer[idx]);
    assert (dc_framebuffer[idx]);
    assert (fb_old && !fb_new && fb_collision);
    assert (dc_old && !dc_new);
    tick();
    assert (!framebuffer[idx]);
    assert (!dc_framebuffer[idx]);
    fb_draw_we = '0;
  end

  for (idx = '0; idx < 256; idx++) begin
    sprite_byte = 8'(idx);
    for (jdx = '0; jdx < 8; jdx++) begin
    sprite_bit = 3'(jdx);
    sprite_base_x = 6'd63;
    sprite_base_y = 5'd31;
    sprite_row = 4'd15;
    #1;
    assert (sprite_pixel_on == sprite_byte[7 - sprite_bit]);
    assert (sprite_draw_x == ((6'd63 + {3'b000, sprite_bit}) &
      6'h3f));
    assert (sprite_draw_y == ((5'd31 + {1'b0, sprite_row}) & 5'h1f))
      ;
    end
  end

  fb_clear = '1;
  tick();
  fb_clear = '0;
  fb_draw_we = '1;
  fb_x = '0;
  fb_y = '0;
  tick();
  fb_draw_we = '0;
  repeat (2048) begin
    tick();
    assert (scan_valid);
    assert ({1'b0, scan_x} < 7'd64 && {1'b0, scan_y} < 6'd32);
    assert (scan_pixel === 1'b0 || scan_pixel === 1'b1);
  end

  ram_we = '1;
  for (idx = '0; idx < 256; idx++) begin
    ram_waddr = (12'h300 + 12'(idx)) & 12'hfff;
    ram_wdata = 8'(idx) ^ 8'ha5;
    tick();
  end
  ram_we = '0;
  for (idx = '0; idx < 256; idx++) begin
    ram_raddr0 = (12'h300 + 12'(idx)) & 12'hfff;
    ram_raddr1 = (12'h300 + 12'(255 - idx)) & 12'hfff;
    tick();
    assert (ram_rdata0 == (8'(idx) ^ 8'ha5));
    assert (ram_rdata1 == (8'(255 - idx) ^ 8'ha5));
  end

  mem_we = '1;
  mem_waddr = 12'h456;
  mem_wdata = 8'h5a;
  tick();
  mem_we = '0;
  mem_raddr0 = '0;
  mem_raddr1 = 12'h456;
  tick();
  tick();
  assert (mem_rdata0 == 8'hf0);
  assert (mem_rdata1 == 8'h5a);
  for (idx = '0; idx < 96; idx++) begin
    font_addr = 7'(idx);
    map_addr = 12'(idx);
    #1;
    assert (map_is_font == (map_addr <=
    chip8_memmap_pkg::CHIP8_FONT_LAST));
    assert (map_is_program == (map_addr >=
    chip8_memmap_pkg::CHIP8_ROM_BASE_ADDR));
    if (idx >= 80) assert (font_data == 8'h00);
  end
  map_addr = chip8_memmap_pkg::CHIP8_ROM_BASE_ADDR;
  #1 assert (!map_is_font && map_is_program);

  loader_valid = '1;
  loader_offset = 12'h123;
  loader_data_i = 8'hbc;
  tick();
  assert (!loader_we);
  loader_valid = '0;
  tick();
  assert (loader_we && loader_addr == ((chip8_pkg::CHIP8_ROM_BASE +
    12'h123) & 12'hfff) && loader_data_o == 8'hbc);
  tick();
  assert (!loader_we);

  arb_cpu_we = '1;
  arb_cpu_addr = 12'h111;
  arb_cpu_data = 8'h11;
  arb_loader_we = '0;
  arb_loader_addr = 12'h222;
  arb_loader_data = 8'h22;
  #1;
  assert (arb_mem_we && arb_mem_addr == 12'h111 && arb_mem_data == 8'h11);
  arb_loader_we = '1;
  #1;
  assert (arb_mem_we && arb_mem_addr == 12'h222 && arb_mem_data == 8'h22);

  $display("CHIP-8 exhaustive block regression PASS");
  $finish;
  end
endmodule

`default_nettype wire

// EOF

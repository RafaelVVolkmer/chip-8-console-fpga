// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_core.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 CPU core controller.
// =============================================================================
//
// Responsibilities:
// - Sequence instruction fetch, decode, execute and side effects.
// - Hold architectural state, program counter and register flow.
// - Coordinate memory, timer, keypad and video interactions.
//
// Characteristics:
// - Synchronous in-order control path.
// - Uses explicit state machines for skip, draw and trap flows.
// - Keeps combinational helpers local to opcode decisions.
//
// Design notes:
// - Keep control transitions visible instead of hiding them in nested logic.
// =============================================================================
`default_nettype none

module chip8_core #(
  parameter int CLK_HZ = 6000000,
  parameter int TICK_HZ = chip8_config_pkg::CHIP8_TIMER_HZ,
  parameter bit TRAP_ILLEGAL = 1'b0,
  parameter chip8_core_pkg::chip8_illegal_policy_t ILLEGAL_POLICY =
    chip8_core_pkg::ILLEGAL_AS_NOP
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        cpu_enable_i,
  input  logic [15:0] keys_i,
  input  logic        rom_load_valid_i,
  output logic        rom_load_ready_o,
  input  logic [11:0] rom_load_offset_i,
  input  logic [7:0]  rom_load_data_i,
  output logic        display_valid_o,
  output logic [5:0]  display_x_o,
  output logic [4:0]  display_y_o,
  output logic        display_pixel_o,
  input  logic [10:0] framebuffer_scan_addr_i,
  output logic        framebuffer_scan_pixel_o,
  output logic [2047:0] framebuffer_o,
  output logic [11:0] pc_o,
  output logic [31:0] debug_status_o,
  output logic [31:0] scb_hfsr_o,
  output logic [31:0] scb_cfsr_o,
  output logic [31:0] scb_mmfar_o,
  output logic [31:0] scb_bfar_o,
  output logic [31:0] scb_shcsr_o,
  output logic [31:0] scb_dfsr_o,
  output logic [31:0] scb_afsr_o,
  output logic        sound_active_o,
  output logic        halted_o
);
  chip8_core_pkg::chip8_state_t state_q;
  chip8_core_pkg::chip8_state_t state_d;

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam chip8_core_pkg::chip8_state_t CORE_STATE_FETCH =
    chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
  localparam chip8_core_pkg::chip8_state_t CORE_STATE_MEM_READ =
    chip8_core_pkg::CHIP8_CORE_PKG_STATE_MEM_READ;
  localparam chip8_core_pkg::chip8_state_t CORE_STATE_WAIT_KEY =
    chip8_core_pkg::CHIP8_CORE_PKG_STATE_WAIT_KEY;
  localparam chip8_core_pkg::chip8_state_t CORE_STATE_BCD0 =
    chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD0;
  localparam chip8_core_pkg::chip8_state_t CORE_STATE_STORE =
    chip8_core_pkg::CHIP8_CORE_PKG_STATE_STORE;
  localparam chip8_core_pkg::chip8_state_t CORE_STATE_LOAD =
    chip8_core_pkg::CHIP8_CORE_PKG_STATE_LOAD;
  localparam chip8_core_pkg::chip8_state_t CORE_STATE_ALU_FLAG =
    chip8_core_pkg::CHIP8_CORE_PKG_STATE_ALU_FLAG;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [11:0] pc_q;
  logic [11:0] pc_d;
  logic [11:0] index_reg_q;
  logic [11:0] index_reg_d;
  logic halted_q;
  logic halted_d;

  logic stack_push_we;
  logic stack_pop_we;
  logic [11:0] stack_push_data;
  logic [11:0] stack_pop_data;

  logic [7:0] delay_timer_value;
  logic [7:0] sound_timer_value;
  logic timer_sound_active;
  logic timer_delay_we;
  logic timer_sound_we;
  logic [7:0] timer_delay_wdata;
  logic [7:0] timer_sound_wdata;

  logic key_selected_pressed;
  logic key_any_pressed;
  logic [3:0] key_first_pressed;
  logic [15:0] key_sample;
  logic [3:0] io_addr;
  logic [7:0] io_rdata;

  logic skip_condition;
  logic [11:0] pc_plus_2;
  logic [11:0] pc_plus_4;
  logic [11:0] jump_v0;
  logic [5:0] datapath_draw_x;
  logic [4:0] datapath_draw_y;

  logic rng_advance_en;
  logic [7:0] rng_next_value;

  logic [15:0] opcode_q;
  logic [15:0] opcode_d;
  logic [15:0] fetched_opcode;
  logic [3:0] opcode_class;
  logic [11:0] nnn;
  logic [7:0] kk;
  logic [3:0] x_idx;
  logic [3:0] y_idx;
  logic [3:0] n;
  chip8_core_pkg::chip8_decoded_t decoded;

  logic [5:0] draw_x;
  logic [4:0] draw_y;
  logic [5:0] draw_base_x_q;
  logic [4:0] draw_base_y_q;
  logic [3:0] draw_n_q;
  logic [2:0] draw_bit_q;
  logic [3:0] draw_row_q;
  logic [7:0] draw_sprite_byte_q;
  logic draw_byte_valid_q;
  logic draw_collision_accum_q;
  logic [5:0] draw_base_x_d;
  logic [4:0] draw_base_y_d;
  logic [3:0] draw_n_d;
  logic [2:0] draw_bit_d;
  logic [3:0] draw_row_d;
  logic [7:0] draw_sprite_byte_d;
  logic draw_byte_valid_d;
  logic draw_collision_accum_d;

  logic [3:0] burst_idx_q;
  logic [3:0] saved_x_q;
  logic [3:0] burst_idx_d;
  logic [3:0] saved_x_d;

  logic [7:0] vx;
  logic [7:0] vy;
  logic [7:0] v0;
  logic [7:0] v_burst;
  logic v_we;
  logic [3:0] v_waddr;
  logic [7:0] v_wdata;

  logic [11:0] mem_raddr0;
  logic [11:0] mem_raddr1;
  logic [11:0] fetch_raddr0;
  logic [11:0] fetch_raddr1;
  logic [11:0] prefetch_pc;
  logic [11:0] prefetch_raddr1;
  logic [15:0] prefetch_opcode;
  logic prefetch_eligible;
  logic prefetch_flush;
  logic prefetch_fill_valid;
  logic prefetch_consume;
  logic prefetch_hit;
  logic fetch_read_valid_q;
  logic fetch_read_valid_d;
  logic [7:0] mem_rdata0;
  logic [7:0] mem_rdata1;
  logic mem_we;
  logic [11:0] mem_waddr;
  logic [7:0] mem_wdata;
  logic loader_mem_we;
  logic [11:0] loader_mem_addr;
  logic [7:0] loader_mem_data;
  logic ram_we;
  logic [11:0] ram_waddr;
  logic [7:0] ram_wdata;

  logic display_clear;
  logic display_draw_we;
  logic display_valid_q;
  logic display_valid_d;
  logic [5:0] display_x_q;
  logic [5:0] display_x_d;
  logic [4:0] display_y_q;
  logic [4:0] display_y_d;
  logic display_pixel_q;
  logic display_pixel_d;
  logic display_old_pixel;
  logic display_new_pixel;
  logic display_collision;
  logic sprite_pixel_on;

  logic sys_cls;
  logic sys_ret;
  logic key_skip;
  logic alu_simple_write;
  logic alu_flag_write;
  logic legal_opcode;
  logic illegal_as_nop;
  logic illegal_trap;
  logic illegal_halt;
  logic control_legal;
  logic fault_illegal;

  chip8_alu_pkg::chip8_alu_op_t alu_op;
  logic [7:0] alu_y;
  logic alu_flag;
  logic alu_flag_value_q;
  logic alu_flag_value_d;

  logic [3:0] bcd_hundreds;
  logic [3:0] bcd_tens;
  logic [3:0] bcd_ones;
  logic bcd_mem_we;
  logic [11:0] bcd_mem_waddr;
  logic [7:0] bcd_mem_wdata;
  chip8_core_pkg::chip8_state_t bcd_state_d;

  logic draw_seq_v_we;
  logic [3:0] draw_seq_v_waddr;
  logic [7:0] draw_seq_v_wdata;
  logic [7:0] draw_seq_sprite_byte_d;
  logic draw_seq_byte_valid_d;
  logic [2:0] draw_seq_bit_d;
  logic [3:0] draw_seq_row_d;
  logic draw_seq_collision_d;
  chip8_core_pkg::chip8_state_t draw_seq_state_d;

  logic burst_mem_we;
  logic [11:0] burst_mem_waddr;
  logic [7:0] burst_mem_wdata;
  logic burst_v_we;
  logic [3:0] burst_v_waddr;
  logic [7:0] burst_v_wdata;
  logic [3:0] burst_idx_seq_d;
  chip8_core_pkg::chip8_state_t burst_state_d;

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam chip8_core_pkg::chip8_illegal_policy_t
    EFFECTIVE_ILLEGAL_POLICY = TRAP_ILLEGAL ?
      chip8_core_pkg::ILLEGAL_TRAP : ILLEGAL_POLICY;
  localparam logic [11:0] CHIP8_CORE_ADDR_MASK = 12'hfff;
  localparam logic [15:0] CHIP8_CORE_CLEAR_SCREEN_OPCODE = 16'h00e0;
  localparam logic [15:0] CHIP8_CORE_RETURN_OPCODE = 16'h00ee;
  localparam logic [7:0] CHIP8_CORE_KEY_PRESSED_IMM = 8'h9e;
  localparam logic [7:0] CHIP8_CORE_KEY_RELEASED_IMM = 8'ha1;
  localparam logic [7:0] CHIP8_CORE_WAIT_KEY_IMM = 8'h0a;
  localparam logic [3:0] CHIP8_CORE_ALU_SIMPLE_LAST_NIBBLE = 4'h3;
  localparam logic [3:0] CHIP8_CORE_ALU_OR_NIBBLE = 4'h1;
  localparam logic [3:0] CHIP8_CORE_ALU_AND_NIBBLE = 4'h2;
  localparam logic [3:0] CHIP8_CORE_ALU_XOR_NIBBLE = 4'h3;
  localparam logic [3:0] CHIP8_CORE_ALU_ADD_NIBBLE = 4'h4;
  localparam logic [3:0] CHIP8_CORE_ALU_SUB_NIBBLE = 4'h5;
  localparam logic [3:0] CHIP8_CORE_ALU_SHR_NIBBLE = 4'h6;
  localparam logic [3:0] CHIP8_CORE_ALU_RSUB_NIBBLE = 4'h7;
  localparam logic [3:0] CHIP8_CORE_ALU_SHL_NIBBLE = 4'he;
  localparam logic [5:0] CHIP8_CORE_DISPLAY_LAST_X = 6'd63;
  localparam logic [4:0] CHIP8_CORE_DISPLAY_LAST_Y = 5'd31;
  localparam logic [3:0] CHIP8_CORE_OPCODE_ADD_IMM_CLASS = 4'h7;
  localparam logic [3:0] CHIP8_CORE_EMPTY_SPRITE_HEIGHT = 4'h0;
  localparam logic [3:0] CHIP8_CORE_VF_INDEX = 4'hf;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign pc_o = pc_q;
  assign halted_o = halted_q;
  assign sound_active_o = timer_sound_active;
  assign display_valid_o = display_valid_q;
  assign display_x_o = display_x_q;
  assign display_y_o = display_y_q;
  assign display_pixel_o = display_pixel_q;

  assign prefetch_pc = pc_plus_2;
  assign prefetch_raddr1 = (prefetch_pc + 12'd1) & CHIP8_CORE_ADDR_MASK;
  assign prefetch_eligible =
    cpu_enable_i &
    (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC) &
    !halted_q &
    legal_opcode &
    (
      ((decoded.op == chip8_core_pkg::OP_SYS) && sys_cls) |
      (decoded.op == chip8_core_pkg::OP_LOAD_IMM) |
      (decoded.op == chip8_core_pkg::OP_ADD_IMM) |
      ((decoded.op == chip8_core_pkg::OP_ALU) && alu_simple_write) |
      (decoded.op == chip8_core_pkg::OP_LOAD_I) |
      (decoded.op == chip8_core_pkg::OP_RANDOM) |
      (decoded.op == chip8_core_pkg::OP_TIMER_READ) |
      (decoded.op == chip8_core_pkg::OP_TIMER_DELAY_WRITE) |
      (decoded.op == chip8_core_pkg::OP_TIMER_SOUND_WRITE) |
      (decoded.op == chip8_core_pkg::OP_ADD_I) |
      (decoded.op == chip8_core_pkg::OP_FONT_ADDR)
    );
  assign prefetch_flush =
    !cpu_enable_i |
    ram_we |
    loader_mem_we |
    ((state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC) &
      !prefetch_eligible);
  assign prefetch_fill_valid =
    (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH) &
    fetch_read_valid_q;
  assign prefetch_consume = prefetch_fill_valid & prefetch_hit;

  assign mem_raddr0 = (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_LOAD) ?
    ((index_reg_q + {8'h00, burst_idx_q}) & CHIP8_CORE_ADDR_MASK) :
    prefetch_eligible ? prefetch_pc :
      fetch_raddr0;
  assign mem_raddr1 =
    ((state_q == CORE_STATE_MEM_READ) &&
     (decoded.op == chip8_core_pkg::OP_DRAW)) ?
    ((index_reg_q + {8'h00, draw_row_q}) & CHIP8_CORE_ADDR_MASK) :
    prefetch_eligible ? prefetch_raddr1 :
      fetch_raddr1;

  assign sys_cls = opcode_q == CHIP8_CORE_CLEAR_SCREEN_OPCODE;
  assign sys_ret = opcode_q == CHIP8_CORE_RETURN_OPCODE;
  assign key_skip = ((kk == CHIP8_CORE_KEY_PRESSED_IMM) &
    key_selected_pressed) | ((kk == CHIP8_CORE_KEY_RELEASED_IMM) &
      !key_selected_pressed);
  assign alu_simple_write =
    opcode_q[3:0] <= CHIP8_CORE_ALU_SIMPLE_LAST_NIBBLE;
  assign alu_flag_write =
    (opcode_q[3:0] == CHIP8_CORE_ALU_ADD_NIBBLE) |
    (opcode_q[3:0] == CHIP8_CORE_ALU_SUB_NIBBLE) |
    (opcode_q[3:0] == CHIP8_CORE_ALU_SHR_NIBBLE) |
    (opcode_q[3:0] == CHIP8_CORE_ALU_RSUB_NIBBLE) |
    (opcode_q[3:0] == CHIP8_CORE_ALU_SHL_NIBBLE);

  assign legal_opcode = control_legal;
  assign illegal_as_nop = EFFECTIVE_ILLEGAL_POLICY ==
    chip8_core_pkg::ILLEGAL_AS_NOP;
  assign illegal_trap = EFFECTIVE_ILLEGAL_POLICY ==
    chip8_core_pkg::ILLEGAL_TRAP;
  assign illegal_halt = EFFECTIVE_ILLEGAL_POLICY ==
    chip8_core_pkg::ILLEGAL_HALT;
  assign fault_illegal =
    (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC) &
    !halted_q &
    !illegal_as_nop &
    !legal_opcode;

  assign display_clear =
    cpu_enable_i &
    (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC) &
    !halted_q &
    sys_cls;
  assign display_draw_we = cpu_enable_i &
    (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_DRAW) &
    !halted_q &
    draw_byte_valid_q &
    sprite_pixel_on;
  assign display_valid_d = display_draw_we;
  assign display_x_d = draw_x;
  assign display_y_d = draw_y;
  assign display_pixel_d = display_new_pixel;
  assign rng_advance_en =
    cpu_enable_i &
    (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC) &
    !halted_q &
    (decoded.op == chip8_core_pkg::OP_RANDOM);

  chip8_fetch u_fetch (
    .pc_i(pc_q),
    .mem_hi_i(mem_rdata0),
    .mem_lo_i(mem_rdata1),
    .raddr_hi_o(fetch_raddr0),
    .raddr_lo_o(fetch_raddr1),
    .opcode_o(fetched_opcode)
  );

  chip8_prefetch_queue u_prefetch_queue (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(prefetch_flush),
    .fill_valid_i(prefetch_fill_valid),
    .fill_pc_i(pc_q),
    .fill_opcode_i(fetched_opcode),
    .consume_i(prefetch_consume),
    .consume_pc_i(pc_q),
    .hit_o(prefetch_hit),
    .opcode_o(prefetch_opcode)
  );

  chip8_decode u_decode (
    .opcode_i(opcode_q),
    .class_o(opcode_class),
    .x_o(x_idx),
    .y_o(y_idx),
    .n_o(n),
    .kk_o(kk),
    .nnn_o(nnn),
    .decoded_o(decoded)
  );

  chip8_control u_control (
    .opcode_class_i(opcode_class),
    .kk_i(kk),
    .decoded_i(decoded),
    .is_draw_o(),
    .is_wait_key_o(),
    .is_timer_write_o(),
    .is_memory_burst_o(),
    .uses_memory_o(),
    .uses_display_o(),
    .uses_timer_o(),
    .uses_keypad_o(),
    .legal_o(control_legal),
    .first_uop_o()
  );

  chip8_datapath u_datapath (
    .draw_x_value_i(vx[5:0]),
    .draw_y_value_i(vy[4:0]),
    .v0_i(v0),
    .nnn_i(nnn),
    .pc_i(pc_q),
    .pc_plus_2_o(pc_plus_2),
    .pc_plus_4_o(pc_plus_4),
    .jump_v0_o(jump_v0),
    .draw_x_o(datapath_draw_x),
    .draw_y_o(datapath_draw_y)
  );

  chip8_skip_unit u_skip_unit (
    .opcode_class_i(opcode_class),
    .vx_i(vx),
    .vy_i(vy),
    .kk_i(kk),
    .n_i(n),
    .skip_o(skip_condition)
  );

  chip8_regfile u_regfile (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .x_addr_i(x_idx),
    .y_addr_i(y_idx),
    .dbg_addr_i((state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_DRAW) ?
      CHIP8_CORE_VF_INDEX : burst_idx_q),
    .we_i(v_we),
    .waddr_i(v_waddr),
    .wdata_i(v_wdata),
    .x_data_o(vx),
    .y_data_o(vy),
    .dbg_data_o(v_burst),
    .v0_data_o(v0),
    .vf_data_o()
  );

  chip8_rom_loader u_rom_loader (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .valid_i(rom_load_valid_i),
    .ready_o(rom_load_ready_o),
    .offset_i(rom_load_offset_i),
    .data_i(rom_load_data_i),
    .mem_we_o(loader_mem_we),
    .mem_addr_o(loader_mem_addr),
    .mem_data_o(loader_mem_data)
  );

  chip8_mem_arbiter u_mem_arbiter (
    .cpu_we_i(mem_we),
    .cpu_addr_i(mem_waddr),
    .cpu_data_i(mem_wdata),
    .loader_we_i(loader_mem_we),
    .loader_addr_i(loader_mem_addr),
    .loader_data_i(loader_mem_data),
    .mem_we_o(ram_we),
    .mem_addr_o(ram_waddr),
    .mem_data_o(ram_wdata)
  );

  chip8_memory u_memory (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .raddr0_i(mem_raddr0),
    .raddr1_i(mem_raddr1),
    .we_i(ram_we),
    .waddr_i(ram_waddr),
    .wdata_i(ram_wdata),
    .rdata0_o(mem_rdata0),
    .rdata1_o(mem_rdata1)
  );

  chip8_alu u_alu (
    .op_i(alu_op),
    .a_i(vx),
    .b_i((opcode_class == CHIP8_CORE_OPCODE_ADD_IMM_CLASS) ? kk : vy),
    .y_o(alu_y),
    .flag_o(alu_flag)
  );

  chip8_stack u_stack (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .push_we_i(stack_push_we),
    .pop_we_i(stack_pop_we),
    .push_data_i(stack_push_data),
    .pop_data_o(stack_pop_data),
    .overflow_o(),
    .underflow_o()
  );

  chip8_rng u_rng (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .advance_en_i(rng_advance_en),
    .next_value_o(rng_next_value)
  );

  chip8_sprite_blitter u_sprite_blitter (
    .sprite_byte_i(draw_sprite_byte_q),
    .bit_i(draw_bit_q),
    .base_x_i(draw_base_x_q),
    .base_y_i(draw_base_y_q),
    .row_i(draw_row_q),
    .pixel_on_o(sprite_pixel_on),
    .draw_x_o(draw_x),
    .draw_y_o(draw_y)
  );

  chip8_collision_unit u_collision_unit (
    .draw_we_i(sprite_pixel_on),
    .old_pixel_i(display_old_pixel),
    .collision_o(display_collision)
  );

  chip8_display_controller u_display (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .clear_i(display_clear),
    .draw_we_i(display_draw_we),
    .draw_x_i(draw_x),
    .draw_y_i(draw_y),
    .scan_addr_i(framebuffer_scan_addr_i),
    .scan_pixel_o(framebuffer_scan_pixel_o),
    .old_pixel_o(display_old_pixel),
    .new_pixel_o(display_new_pixel),
    .framebuffer_o(framebuffer_o)
  );

  chip8_timer #(
    .CLK_HZ(CLK_HZ),
    .TICK_HZ(TICK_HZ)
  ) u_timer (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .delay_we_i(timer_delay_we),
    .sound_we_i(timer_sound_we),
    .delay_wdata_i(timer_delay_wdata),
    .sound_wdata_i(timer_sound_wdata),
    .delay_o(delay_timer_value),
    .sound_o(sound_timer_value),
    .sound_active_o(timer_sound_active)
  );

  chip8_keypad u_keypad (
    .keys_i(keys_i),
    .select_i(vx[3:0]),
    .selected_pressed_o(key_selected_pressed),
    .any_pressed_o(key_any_pressed),
    .first_pressed_o(key_first_pressed),
    .keys_o(key_sample)
  );

  chip8_io_mux u_io_mux (
    .addr_i(io_addr),
    .delay_i(delay_timer_value),
    .sound_i(sound_timer_value),
    .keys_i(key_sample),
    .key_any_i(key_any_pressed),
    .key_first_i(key_first_pressed),
    .rdata_o(io_rdata)
  );

  chip8_bcd u_bcd (
    .binary_i(vx),
    .hundreds_o(bcd_hundreds),
    .tens_o(bcd_tens),
    .ones_o(bcd_ones)
  );

  chip8_draw_sequencer u_draw_sequencer (
    .draw_byte_valid_i(draw_byte_valid_q),
    .sprite_byte_i(draw_sprite_byte_q),
    .mem_sprite_byte_i(mem_rdata1),
    .draw_bit_i(draw_bit_q),
    .draw_row_i(draw_row_q),
    .draw_n_i(draw_n_q),
    .collision_accum_i(draw_collision_accum_q),
    .sprite_pixel_on_i(sprite_pixel_on),
    .display_collision_i(display_collision),
    .sprite_byte_d_o(draw_seq_sprite_byte_d),
    .draw_byte_valid_d_o(draw_seq_byte_valid_d),
    .draw_bit_d_o(draw_seq_bit_d),
    .draw_row_d_o(draw_seq_row_d),
    .collision_accum_d_o(draw_seq_collision_d),
    .v_we_o(draw_seq_v_we),
    .v_waddr_o(draw_seq_v_waddr),
    .v_wdata_o(draw_seq_v_wdata),
    .state_d_o(draw_seq_state_d)
  );

  chip8_bcd_writer u_bcd_writer (
    .state_i(state_q),
    .index_reg_i(index_reg_q),
    .hundreds_i(bcd_hundreds),
    .tens_i(bcd_tens),
    .ones_i(bcd_ones),
    .mem_we_o(bcd_mem_we),
    .mem_waddr_o(bcd_mem_waddr),
    .mem_wdata_o(bcd_mem_wdata),
    .state_d_o(bcd_state_d)
  );

  chip8_mem_burst u_mem_burst (
    .store_i(state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_STORE),
    .load_commit_i(
      (state_q == CORE_STATE_MEM_READ) &&
      (decoded.op == chip8_core_pkg::OP_LOAD_REGS)
    ),
    .index_reg_i(index_reg_q),
    .burst_idx_i(burst_idx_q),
    .saved_x_i(saved_x_q),
    .reg_data_i(v_burst),
    .mem_data_i(mem_rdata0),
    .mem_we_o(burst_mem_we),
    .mem_waddr_o(burst_mem_waddr),
    .mem_wdata_o(burst_mem_wdata),
    .v_we_o(burst_v_we),
    .v_waddr_o(burst_v_waddr),
    .v_wdata_o(burst_v_wdata),
    .burst_idx_d_o(burst_idx_seq_d),
    .state_d_o(burst_state_d)
  );

  chip8_debug_regs u_debug_regs (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .pc_i(pc_q),
    .opcode_i(opcode_q),
    .state_i(state_q),
    .decoded_i(decoded),
    .halted_i(halted_q),
    .fault_illegal_i(fault_illegal),
    .pc_o(),
    .opcode_o(),
    .state_o(),
    .status_o(debug_status_o),
    .scb_hfsr_o(scb_hfsr_o),
    .scb_cfsr_o(scb_cfsr_o),
    .scb_mmfar_o(scb_mmfar_o),
    .scb_bfar_o(scb_bfar_o),
    .scb_shcsr_o(scb_shcsr_o),
    .scb_dfsr_o(scb_dfsr_o),
    .scb_afsr_o(scb_afsr_o)
  );

  assign io_addr = (kk == CHIP8_CORE_WAIT_KEY_IMM) ?
    chip8_periph_pkg::CHIP8_IO_KEY_FIRST :
    chip8_periph_pkg::CHIP8_IO_DELAY;

  assign alu_op =
    (opcode_class == CHIP8_CORE_OPCODE_ADD_IMM_CLASS) ?
      chip8_alu_pkg::CHIP8_ALU_ADD_IMM :
    (opcode_q[3:0] == CHIP8_CORE_ALU_OR_NIBBLE) ?
      chip8_alu_pkg::CHIP8_ALU_OR :
    (opcode_q[3:0] == CHIP8_CORE_ALU_AND_NIBBLE) ?
      chip8_alu_pkg::CHIP8_ALU_AND :
    (opcode_q[3:0] == CHIP8_CORE_ALU_XOR_NIBBLE) ?
      chip8_alu_pkg::CHIP8_ALU_XOR :
    (opcode_q[3:0] == CHIP8_CORE_ALU_ADD_NIBBLE) ?
      chip8_alu_pkg::CHIP8_ALU_ADD :
    (opcode_q[3:0] == CHIP8_CORE_ALU_SUB_NIBBLE) ?
      chip8_alu_pkg::CHIP8_ALU_SUB :
    (opcode_q[3:0] == CHIP8_CORE_ALU_SHR_NIBBLE) ?
      chip8_alu_pkg::CHIP8_ALU_SHR :
    (opcode_q[3:0] == CHIP8_CORE_ALU_RSUB_NIBBLE) ?
      chip8_alu_pkg::CHIP8_ALU_RSUB :
    (opcode_q[3:0] == CHIP8_CORE_ALU_SHL_NIBBLE) ?
      chip8_alu_pkg::CHIP8_ALU_SHL :
    chip8_alu_pkg::CHIP8_ALU_MOV;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  // The control path computes defaults first, then selectively overrides
  // them. That keeps the common fetch/decode/skip unit path predictable while
  // still allowing multi-cycle CHIP-8 operations to remain explicit.
  // Ref: Patterson and Ditzel, ACM SIGARCH, DOI 10.1145/641914.641917.
  always_comb begin
    state_d = state_q;
    pc_d = pc_q;
    index_reg_d = index_reg_q;
    halted_d = halted_q;
    opcode_d = opcode_q;
    draw_base_x_d = draw_base_x_q;
    draw_base_y_d = draw_base_y_q;
    draw_n_d = draw_n_q;
    draw_bit_d = draw_bit_q;
    draw_row_d = draw_row_q;
    draw_sprite_byte_d = draw_sprite_byte_q;
    draw_byte_valid_d = draw_byte_valid_q;
    draw_collision_accum_d = draw_collision_accum_q;
    burst_idx_d = burst_idx_q;
    saved_x_d = saved_x_q;
    alu_flag_value_d = alu_flag_value_q;
    fetch_read_valid_d = '0;

    v_we = '0;
    v_waddr = '0;
    v_wdata = '0;
    mem_we = '0;
    mem_waddr = '0;
    mem_wdata = '0;
    stack_push_we = '0;
    stack_pop_we = '0;
    stack_push_data = '0;
    timer_delay_we = '0;
    timer_sound_we = '0;
    timer_delay_wdata = '0;
    timer_sound_wdata = '0;

    if (cpu_enable_i && !halted_q) begin
      unique case (state_q)
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH: begin
          if (prefetch_hit) begin
            opcode_d = prefetch_opcode;
            state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC;
          end else begin
            state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_DECODE;
          end
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_DECODE: begin
          opcode_d = fetched_opcode;
          state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC;
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC: begin
          pc_d = pc_plus_2;
          state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
          fetch_read_valid_d = prefetch_eligible;
          if (!legal_opcode) begin
            pc_d = pc_plus_2;
            state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
            fetch_read_valid_d = '0;
            if (illegal_trap || illegal_halt) begin
              halted_d = '1;
              pc_d = pc_q;
              state_d = illegal_trap ?
                chip8_core_pkg::CHIP8_CORE_PKG_STATE_TRAP :
                  chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
            end
          end else begin
            unique case (decoded.op)
              chip8_core_pkg::OP_SYS: begin
                stack_pop_we = sys_ret;
                pc_d = sys_ret ? stack_pop_data : pc_plus_2;
              end
              chip8_core_pkg::OP_JUMP: pc_d = nnn;
              chip8_core_pkg::OP_CALL: begin
                stack_push_we = '1;
                stack_push_data = pc_plus_2;
                pc_d = nnn;
              end
              chip8_core_pkg::OP_SKIP_EQ_IMM,
              chip8_core_pkg::OP_SKIP_NE_IMM,
              chip8_core_pkg::OP_SKIP_EQ_REG,
              chip8_core_pkg::OP_SKIP_NE_REG: begin
                pc_d = skip_condition ? pc_plus_4 :
                  pc_plus_2;
              end
              chip8_core_pkg::OP_LOAD_IMM: begin
                v_we = '1;
                v_waddr = x_idx;
                v_wdata = kk;
              end
              chip8_core_pkg::OP_ADD_IMM: begin
                v_we = '1;
                v_waddr = x_idx;
                v_wdata = alu_y;
              end
              chip8_core_pkg::OP_ALU: begin
                v_we = alu_simple_write | alu_flag_write;
                v_waddr = x_idx;
                v_wdata = alu_y;
                alu_flag_value_d = alu_flag;
                state_d = alu_flag_write ?
                  CORE_STATE_ALU_FLAG
                  :
                  CORE_STATE_FETCH;
              end
              chip8_core_pkg::OP_LOAD_I: index_reg_d = nnn;
              chip8_core_pkg::OP_JUMP_V0: pc_d = jump_v0;
              chip8_core_pkg::OP_RANDOM: begin
                v_we = '1;
                v_waddr = x_idx;
                v_wdata = rng_next_value & kk;
              end
              chip8_core_pkg::OP_DRAW: begin
                draw_base_x_d = datapath_draw_x;
                draw_base_y_d = datapath_draw_y;
                draw_n_d = n;
                draw_bit_d = '0;
                draw_row_d = '0;
                draw_byte_valid_d = '0;
                draw_collision_accum_d = '0;
                state_d =
                  (n == CHIP8_CORE_EMPTY_SPRITE_HEIGHT) ?
                  CORE_STATE_FETCH
                  :
                  CORE_STATE_MEM_READ;
              end
              chip8_core_pkg::OP_KEY_SKIP: begin
                pc_d = key_skip ? pc_plus_4 : pc_plus_2;
              end
              chip8_core_pkg::OP_TIMER_READ: begin
                v_we = '1;
                v_waddr = x_idx;
                v_wdata = io_rdata;
              end
              chip8_core_pkg::OP_WAIT_KEY: begin
                pc_d = pc_q;
                state_d = CORE_STATE_WAIT_KEY;
              end
              chip8_core_pkg::OP_TIMER_DELAY_WRITE: begin
                timer_delay_we = '1;
                timer_delay_wdata = vx;
              end
              chip8_core_pkg::OP_TIMER_SOUND_WRITE: begin
                timer_sound_we = '1;
                timer_sound_wdata = vx;
              end
              chip8_core_pkg::OP_ADD_I: begin
                index_reg_d = (index_reg_q + {4'h0, vx}) &
                  CHIP8_CORE_ADDR_MASK;
              end
              chip8_core_pkg::OP_FONT_ADDR: begin
                index_reg_d = ({6'h00, vx[3:0], 2'b00} +
                  {8'h00, vx[3:0]}) & CHIP8_CORE_ADDR_MASK;
              end
              chip8_core_pkg::OP_BCD: begin
                state_d = CORE_STATE_BCD0;
              end
              chip8_core_pkg::OP_STORE_REGS: begin
                saved_x_d = x_idx;
                burst_idx_d = '0;
                state_d = CORE_STATE_STORE;
              end
              chip8_core_pkg::OP_LOAD_REGS: begin
                saved_x_d = x_idx;
                burst_idx_d = '0;
                state_d = CORE_STATE_LOAD;
              end
              default: ;
            endcase
          end
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_DRAW: begin
          draw_sprite_byte_d = draw_seq_sprite_byte_d;
          draw_byte_valid_d = draw_seq_byte_valid_d;
          draw_bit_d = draw_seq_bit_d;
          draw_row_d = draw_seq_row_d;
          draw_collision_accum_d = draw_seq_collision_d;
          state_d = draw_seq_state_d;
          v_we = draw_seq_v_we;
          v_waddr = draw_seq_v_waddr;
          v_wdata = draw_seq_v_wdata;
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_WAIT_KEY: begin
          state_d = key_any_pressed ?
            CORE_STATE_FETCH :
            CORE_STATE_WAIT_KEY;
          pc_d = key_any_pressed ? pc_plus_2 : pc_q;
          v_we = key_any_pressed;
          v_waddr = x_idx;
          v_wdata = {4'h0, key_first_pressed};
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_MEM_READ: begin
          unique case (decoded.op)
            chip8_core_pkg::OP_DRAW: begin
              state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_DRAW;
            end
            chip8_core_pkg::OP_LOAD_REGS: begin
              v_we = burst_v_we;
              v_waddr = burst_v_waddr;
              v_wdata = burst_v_wdata;
              state_d = burst_state_d;
              burst_idx_d = burst_idx_seq_d;
            end
            default: begin
              state_d =
                CORE_STATE_FETCH;
            end
          endcase
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD0: begin
          mem_we = bcd_mem_we;
          mem_waddr = bcd_mem_waddr;
          mem_wdata = bcd_mem_wdata;
          state_d = bcd_state_d;
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD1: begin
          mem_we = bcd_mem_we;
          mem_waddr = bcd_mem_waddr;
          mem_wdata = bcd_mem_wdata;
          state_d = bcd_state_d;
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD2: begin
          mem_we = bcd_mem_we;
          mem_waddr = bcd_mem_waddr;
          mem_wdata = bcd_mem_wdata;
          state_d = bcd_state_d;
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_STORE: begin
          mem_we = burst_mem_we;
          mem_waddr = burst_mem_waddr;
          mem_wdata = burst_mem_wdata;
          state_d = burst_state_d;
          burst_idx_d = burst_idx_seq_d;
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_LOAD: begin
          state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_MEM_READ;
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_ALU_FLAG: begin
          v_we = '1;
          v_waddr = CHIP8_CORE_VF_INDEX;
          v_wdata = {7'h00, alu_flag_value_q};
          state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
        end
        chip8_core_pkg::CHIP8_CORE_PKG_STATE_TRAP: begin
          state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_TRAP;
        end
        default: state_d = chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
      endcase
    end
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q <= chip8_pkg::CHIP8_ROM_BASE;
      index_reg_q <= '0;
      opcode_q <= '0;
      state_q <= chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
      draw_base_x_q <= '0;
      draw_base_y_q <= '0;
      draw_n_q <= '0;
      draw_bit_q <= '0;
      draw_row_q <= '0;
      draw_sprite_byte_q <= '0;
      draw_byte_valid_q <= '0;
      draw_collision_accum_q <= '0;
      burst_idx_q <= '0;
      saved_x_q <= '0;
      alu_flag_value_q <= '0;
      fetch_read_valid_q <= '0;
      halted_q <= '0;
      display_valid_q <= '0;
      display_x_q <= '0;
      display_y_q <= '0;
      display_pixel_q <= '0;
    end else if (!cpu_enable_i) begin
      pc_q <= chip8_pkg::CHIP8_ROM_BASE;
      index_reg_q <= '0;
      opcode_q <= '0;
      state_q <= chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
      draw_base_x_q <= '0;
      draw_base_y_q <= '0;
      draw_n_q <= '0;
      draw_bit_q <= '0;
      draw_row_q <= '0;
      draw_sprite_byte_q <= '0;
      draw_byte_valid_q <= '0;
      draw_collision_accum_q <= '0;
      burst_idx_q <= '0;
      saved_x_q <= '0;
      alu_flag_value_q <= '0;
      fetch_read_valid_q <= '0;
      halted_q <= '0;
      display_valid_q <= '0;
      display_x_q <= '0;
      display_y_q <= '0;
      display_pixel_q <= '0;
    end else begin
      pc_q <= pc_d;
      index_reg_q <= index_reg_d;
      opcode_q <= opcode_d;
      state_q <= state_d;
      draw_base_x_q <= draw_base_x_d;
      draw_base_y_q <= draw_base_y_d;
      draw_n_q <= draw_n_d;
      draw_bit_q <= draw_bit_d;
      draw_row_q <= draw_row_d;
      draw_sprite_byte_q <= draw_sprite_byte_d;
      draw_byte_valid_q <= draw_byte_valid_d;
      draw_collision_accum_q <= draw_collision_accum_d;
      burst_idx_q <= burst_idx_d;
      saved_x_q <= saved_x_d;
      alu_flag_value_q <= alu_flag_value_d;
      fetch_read_valid_q <= fetch_read_valid_d;
      halted_q <= halted_d;
      display_valid_q <= display_valid_d;
      display_x_q <= display_x_d;
      display_y_q <= display_y_d;
      display_pixel_q <= display_pixel_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert(
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_DECODE) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_EXEC) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_MEM_READ) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_DRAW) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_WAIT_KEY) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_TRAP) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD0) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD1) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_BCD2) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_STORE) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_LOAD) ||
        (state_q == chip8_core_pkg::CHIP8_CORE_PKG_STATE_ALU_FLAG)
      );
      assert(display_x_o <= CHIP8_CORE_DISPLAY_LAST_X);
      assert(display_y_o <= CHIP8_CORE_DISPLAY_LAST_Y);
    end
  end
`endif
endmodule

`default_nettype wire

// EOF

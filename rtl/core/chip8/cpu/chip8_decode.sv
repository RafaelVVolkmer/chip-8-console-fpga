// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_decode.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 instruction decoder.
// =============================================================================
//
// Responsibilities:
// - Classify opcodes and extract immediate fields.
// - Drive control signals for the CPU datapath and side-effect units.
// - Keep decode rules auditable at the opcode boundary.
//
// Characteristics:
// - Pure combinational decode.
// - Small encodings map directly from instruction bits.
// - Used by the core control path and formal checks.
//
// Design notes:
// - Prefer named opcode classes over magic nibble comparisons.
// =============================================================================
`default_nettype none

module chip8_decode (
  input  logic [15:0] opcode_i,
  output logic [3:0]  class_o,
  output logic [3:0]  x_o,
  output logic [3:0]  y_o,
  output logic [3:0]  n_o,
  output logic [7:0]  kk_o,
  output logic [11:0] nnn_o,
  output chip8_core_pkg::chip8_decoded_t decoded_o
);
  chip8_core_pkg::chip8_decoded_t decoded;
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic alu_simple_write;
  logic alu_flag_write;
  logic legal_sys;
  logic legal_key;
  logic legal_timer_mem;
  logic [15:0] class_sel;


  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [3:0] CHIP8_DECODE_ZERO_NIBBLE = '0;
  localparam logic [3:0] CHIP8_DECODE_ALU_OR_NIBBLE = 4'h1;
  localparam logic [3:0] CHIP8_DECODE_ALU_AND_NIBBLE = 4'h2;
  localparam logic [3:0] CHIP8_DECODE_ALU_XOR_NIBBLE = 4'h3;
  localparam logic [3:0] CHIP8_DECODE_ALU_ADD_NIBBLE = 4'h4;
  localparam logic [3:0] CHIP8_DECODE_ALU_SUB_NIBBLE = 4'h5;
  localparam logic [3:0] CHIP8_DECODE_ALU_SHR_NIBBLE = 4'h6;
  localparam logic [3:0] CHIP8_DECODE_ALU_RSUB_NIBBLE = 4'h7;
  localparam logic [3:0] CHIP8_DECODE_ALU_SHL_NIBBLE = 4'he;

  localparam logic [15:0] CHIP8_DECODE_CLEAR_SCREEN_OPCODE = 16'h00e0;
  localparam logic [15:0] CHIP8_DECODE_RETURN_OPCODE = 16'h00ee;

  localparam logic [7:0] CHIP8_DECODE_SKIP_KEY_DOWN_IMM = 8'h9e;
  localparam logic [7:0] CHIP8_DECODE_SKIP_KEY_UP_IMM = 8'ha1;
  localparam logic [7:0] CHIP8_DECODE_READ_DELAY_TIMER_IMM = 8'h07;
  localparam logic [7:0] CHIP8_DECODE_WAIT_KEY_IMM = 8'h0a;
  localparam logic [7:0] CHIP8_DECODE_WRITE_DELAY_TIMER_IMM = 8'h15;
  localparam logic [7:0] CHIP8_DECODE_WRITE_SOUND_TIMER_IMM = 8'h18;
  localparam logic [7:0] CHIP8_DECODE_ADD_I_IMM = 8'h1e;
  localparam logic [7:0] CHIP8_DECODE_FONT_ADDR_IMM = 8'h29;
  localparam logic [7:0] CHIP8_DECODE_BCD_STORE_IMM = 8'h33;
  localparam logic [7:0] CHIP8_DECODE_STORE_REGS_IMM = 8'h55;
  localparam logic [7:0] CHIP8_DECODE_LOAD_REGS_IMM = 8'h65;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign class_o = opcode_i[15:12];
  assign x_o = opcode_i[11:8];
  assign y_o = opcode_i[7:4];
  assign n_o = opcode_i[3:0];
  assign kk_o = opcode_i[7:0];
  assign nnn_o = opcode_i[11:0];
  assign class_sel = 16'h0001 << class_o;

  assign alu_simple_write = opcode_i[3:0] <= CHIP8_DECODE_ALU_XOR_NIBBLE;
  assign alu_flag_write =
    (opcode_i[3:0] == CHIP8_DECODE_ALU_ADD_NIBBLE) |
    (opcode_i[3:0] == CHIP8_DECODE_ALU_SUB_NIBBLE) |
    (opcode_i[3:0] == CHIP8_DECODE_ALU_SHR_NIBBLE) |
    (opcode_i[3:0] == CHIP8_DECODE_ALU_RSUB_NIBBLE) |
    (opcode_i[3:0] == CHIP8_DECODE_ALU_SHL_NIBBLE);
  assign legal_sys =
    (opcode_i == CHIP8_DECODE_CLEAR_SCREEN_OPCODE) |
    (opcode_i == CHIP8_DECODE_RETURN_OPCODE);
  assign legal_key = (opcode_i[7:0] == CHIP8_DECODE_SKIP_KEY_DOWN_IMM) |
    (opcode_i[7:0] == CHIP8_DECODE_SKIP_KEY_UP_IMM);
  assign legal_timer_mem =
    (opcode_i[7:0] == CHIP8_DECODE_READ_DELAY_TIMER_IMM) |
    (opcode_i[7:0] == CHIP8_DECODE_WAIT_KEY_IMM) |
    (opcode_i[7:0] == CHIP8_DECODE_WRITE_DELAY_TIMER_IMM) |
    (opcode_i[7:0] == CHIP8_DECODE_WRITE_SOUND_TIMER_IMM) |
    (opcode_i[7:0] == CHIP8_DECODE_ADD_I_IMM) |
    (opcode_i[7:0] == CHIP8_DECODE_FONT_ADDR_IMM) |
    (opcode_i[7:0] == CHIP8_DECODE_BCD_STORE_IMM) |
    (opcode_i[7:0] == CHIP8_DECODE_STORE_REGS_IMM) |
    (opcode_i[7:0] == CHIP8_DECODE_LOAD_REGS_IMM);

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin
    decoded = '0;
    decoded.opcode = opcode_i;
    decoded.opcode_class = class_o;
    decoded.x = opcode_i[11:8];
    decoded.y = opcode_i[7:4];
    decoded.n = opcode_i[3:0];
    decoded.kk = opcode_i[7:0];
    decoded.nnn = opcode_i[11:0];
    decoded.op = chip8_core_pkg::OP_ILLEGAL;
    decoded.first_uop = chip8_core_pkg::UOP_TRAP;

    // Decode keeps legal-op detection explicit and table-like. Class
    // predicates are one-hot, so downstream control sees a dataflow select
    // instead of a branchy priority chain over the high opcode nibble.
    // Ref: Mahlke et al., predicated execution support, ACM/IEEE ISCA,
    // 1992.
    unique case (1'b1)
      class_sel[chip8_isa_pkg::CHIP8_OP_SYS]: begin
        decoded.op = chip8_core_pkg::OP_SYS;
        decoded.legal = legal_sys;
        decoded.first_uop = legal_sys ? chip8_core_pkg::UOP_EXEC :
          chip8_core_pkg::UOP_TRAP;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_JP]: begin
        decoded.op = chip8_core_pkg::OP_JUMP;
        decoded.legal = '1;
        decoded.first_uop = chip8_core_pkg::UOP_EXEC;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_CALL]: begin
        decoded.op = chip8_core_pkg::OP_CALL;
        decoded.legal = '1;
        decoded.first_uop = chip8_core_pkg::UOP_EXEC;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_SEB]: begin
        decoded.op = chip8_core_pkg::OP_SKIP_EQ_IMM;
        decoded.legal = '1;
        decoded.first_uop = chip8_core_pkg::UOP_EXEC;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_SNEB]: begin
        decoded.op = chip8_core_pkg::OP_SKIP_NE_IMM;
        decoded.legal = '1;
        decoded.first_uop = chip8_core_pkg::UOP_EXEC;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_SER]: begin
        decoded.op = chip8_core_pkg::OP_SKIP_EQ_REG;
        decoded.legal = opcode_i[3:0] == CHIP8_DECODE_ZERO_NIBBLE;
        decoded.first_uop = decoded.legal ?
          chip8_core_pkg::UOP_EXEC : chip8_core_pkg::UOP_TRAP;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_LDB]: begin
        decoded.op = chip8_core_pkg::OP_LOAD_IMM;
        decoded.legal = '1;
        decoded.writes_vx = '1;
        decoded.first_uop = chip8_core_pkg::UOP_EXEC;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_ADDB]: begin
        decoded.op = chip8_core_pkg::OP_ADD_IMM;
        decoded.legal = '1;
        decoded.writes_vx = '1;
        decoded.first_uop = chip8_core_pkg::UOP_EXEC;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_ALU]: begin
        decoded.op = chip8_core_pkg::OP_ALU;
        decoded.legal = alu_simple_write | alu_flag_write;
        decoded.writes_vx = decoded.legal;
        decoded.writes_vf = alu_flag_write;
        decoded.first_uop = decoded.legal ?
          chip8_core_pkg::UOP_EXEC : chip8_core_pkg::UOP_TRAP;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_SNER]: begin
        decoded.op = chip8_core_pkg::OP_SKIP_NE_REG;
        decoded.legal = opcode_i[3:0] == CHIP8_DECODE_ZERO_NIBBLE;
        decoded.first_uop = decoded.legal ?
          chip8_core_pkg::UOP_EXEC : chip8_core_pkg::UOP_TRAP;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_LDI]: begin
        decoded.op = chip8_core_pkg::OP_LOAD_I;
        decoded.legal = '1;
        decoded.first_uop = chip8_core_pkg::UOP_EXEC;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_JPV0]: begin
        decoded.op = chip8_core_pkg::OP_JUMP_V0;
        decoded.legal = '1;
        decoded.first_uop = chip8_core_pkg::UOP_EXEC;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_RND]: begin
        decoded.op = chip8_core_pkg::OP_RANDOM;
        decoded.legal = '1;
        decoded.writes_vx = '1;
        decoded.first_uop = chip8_core_pkg::UOP_EXEC;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_DRW]: begin
        decoded.op = chip8_core_pkg::OP_DRAW;
        decoded.legal = '1;
        decoded.writes_vf = '1;
        decoded.uses_memory = '1;
        decoded.uses_display = '1;
        decoded.first_uop = chip8_core_pkg::UOP_DRAW_PIXEL;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_KEY]: begin
        decoded.op = chip8_core_pkg::OP_KEY_SKIP;
        decoded.legal = legal_key;
        decoded.uses_keypad = decoded.legal;
        decoded.first_uop = decoded.legal ?
          chip8_core_pkg::UOP_EXEC : chip8_core_pkg::UOP_TRAP;
      end
      class_sel[chip8_isa_pkg::CHIP8_OP_MISC]: begin
        decoded.legal = legal_timer_mem;
        decoded.first_uop = decoded.legal ?
          chip8_core_pkg::UOP_EXEC : chip8_core_pkg::UOP_TRAP;
        unique case (opcode_i[7:0])
          CHIP8_DECODE_READ_DELAY_TIMER_IMM: begin
            decoded.op = chip8_core_pkg::OP_TIMER_READ;
            decoded.writes_vx = '1;
            decoded.uses_timer = '1;
          end
          CHIP8_DECODE_WAIT_KEY_IMM: begin
            decoded.op = chip8_core_pkg::OP_WAIT_KEY;
            decoded.writes_vx = '1;
            decoded.uses_keypad = '1;
            decoded.first_uop = chip8_core_pkg::UOP_WAIT_KEY;
          end
          CHIP8_DECODE_WRITE_DELAY_TIMER_IMM: begin
            decoded.op = chip8_core_pkg::OP_TIMER_DELAY_WRITE;
            decoded.uses_timer = '1;
          end
          CHIP8_DECODE_WRITE_SOUND_TIMER_IMM: begin
            decoded.op = chip8_core_pkg::OP_TIMER_SOUND_WRITE;
            decoded.uses_timer = '1;
          end
          CHIP8_DECODE_ADD_I_IMM: begin
            decoded.op = chip8_core_pkg::OP_ADD_I;
          end
          CHIP8_DECODE_FONT_ADDR_IMM: begin
            decoded.op = chip8_core_pkg::OP_FONT_ADDR;
          end
          CHIP8_DECODE_BCD_STORE_IMM: begin
            decoded.op = chip8_core_pkg::OP_BCD;
            decoded.uses_memory = '1;
            decoded.first_uop = chip8_core_pkg::UOP_MEM_WRITE;
          end
          CHIP8_DECODE_STORE_REGS_IMM: begin
            decoded.op = chip8_core_pkg::OP_STORE_REGS;
            decoded.uses_memory = '1;
            decoded.first_uop = chip8_core_pkg::UOP_MEM_WRITE;
          end
          CHIP8_DECODE_LOAD_REGS_IMM: begin
            decoded.op = chip8_core_pkg::OP_LOAD_REGS;
            decoded.writes_vx = '1;
            decoded.uses_memory = '1;
            decoded.first_uop = chip8_core_pkg::UOP_MEM_READ;
          end
          default: ;
        endcase
      end
      default: ;
    endcase
  end

  assign decoded_o = decoded;

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_comb begin
    assert ($onehot(class_sel));
    assert (decoded_o.opcode == opcode_i);
    assert (decoded_o.opcode_class == class_o);
    assert (decoded_o.x == x_o);
    assert (decoded_o.y == y_o);
    assert (decoded_o.n == n_o);
    assert (decoded_o.kk == kk_o);
    assert (decoded_o.nnn == nnn_o);
    if (!decoded_o.legal) begin
      assert (decoded_o.first_uop == chip8_core_pkg::UOP_TRAP);
    end
  end
`endif
endmodule

`default_nettype wire

// EOF

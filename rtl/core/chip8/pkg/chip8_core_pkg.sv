// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_core_pkg.sv
// -----------------------------------------------------------------------------
// @brief Package for shared CHIP-8 Core pkg definitions.
// =============================================================================
//
// Responsibilities:
// - Centralize compile-time constants, encodings and typedefs.
// - Keep imports decoupled from module internals.
// - Provide a single namespace for downstream blocks.
//
// Characteristics:
// - Pure elaboration-time content only.
// - No state or sequential logic.
// - Used by RTL and formal copies alike.
//
// Design notes:
// - Keep shared encodings small and explicit.
// =============================================================================
`default_nettype none

package chip8_core_pkg;
  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // CPU finite-state machine phases owned by chip8_core.
  //
  // Characteristics:
  // - Encodes architectural progress through fetch, decode and side-effect
  //   states.
  // - Keeps multi-cycle CHIP-8 operations explicit instead of hiding them in
  //   helper blocks.
  // - Trap and wait states are terminal/blocking states until external control
  //   or input changes them.
  typedef enum logic [3:0] {
    CHIP8_CORE_PKG_STATE_FETCH,
    CHIP8_CORE_PKG_STATE_DECODE,
    CHIP8_CORE_PKG_STATE_EXEC,
    CHIP8_CORE_PKG_STATE_MEM_READ,
    CHIP8_CORE_PKG_STATE_DRAW,
    CHIP8_CORE_PKG_STATE_WAIT_KEY,
    CHIP8_CORE_PKG_STATE_TRAP,
    CHIP8_CORE_PKG_STATE_BCD0,
    CHIP8_CORE_PKG_STATE_BCD1,
    CHIP8_CORE_PKG_STATE_BCD2,
    CHIP8_CORE_PKG_STATE_STORE,
    CHIP8_CORE_PKG_STATE_LOAD,
    CHIP8_CORE_PKG_STATE_ALU_FLAG
  } chip8_state_t;

  // Decoded architectural operation selected from the 16-bit opcode.
  //
  // Responsibilities:
  // - Carries the opcode intent after decode.
  // - Lets control/datapath logic switch on behavior rather than raw opcode
  //   fields.
  // - Reserves OP_ILLEGAL for trap/NOP policy decisions.
  typedef enum logic [5:0] {
    OP_SYS,
    OP_JUMP,
    OP_CALL,
    OP_SKIP_EQ_IMM,
    OP_SKIP_NE_IMM,
    OP_SKIP_EQ_REG,
    OP_LOAD_IMM,
    OP_ADD_IMM,
    OP_ALU,
    OP_SKIP_NE_REG,
    OP_LOAD_I,
    OP_JUMP_V0,
    OP_RANDOM,
    OP_DRAW,
    OP_KEY_SKIP,
    OP_TIMER_READ,
    OP_WAIT_KEY,
    OP_TIMER_DELAY_WRITE,
    OP_TIMER_SOUND_WRITE,
    OP_ADD_I,
    OP_FONT_ADDR,
    OP_BCD,
    OP_STORE_REGS,
    OP_LOAD_REGS,
    OP_ILLEGAL
  } chip8_op_t;

  // First micro-operation required to complete a decoded instruction.
  //
  // Responsibilities:
  // - Selects the first side-effect path after decode.
  // - Separates register-only instructions from memory, display, wait-key and
  //   trap paths.
  // - Allows chip8_core to advance multi-cycle instructions one explicit phase
  //   at a time.
  typedef enum logic [3:0] {
    UOP_EXEC,
    UOP_MEM_READ,
    UOP_MEM_WRITE,
    UOP_DRAW_PIXEL,
    UOP_WAIT_KEY,
    UOP_TRAP
  } chip8_uop_t;

  // Policy applied when decode marks an opcode illegal.
  //
  // Characteristics:
  // - NOP mode is useful for compatibility experiments.
  // - Trap mode captures debug/status information.
  // - Halt mode stops fetch progress after an illegal instruction.
  typedef enum logic [1:0] {
    ILLEGAL_AS_NOP,
    ILLEGAL_TRAP,
    ILLEGAL_HALT
  } chip8_illegal_policy_t;

  // Fully decoded, static instruction descriptor passed from decode to control
  // and execution.
  //
  // Responsibilities:
  // - Preserve raw opcode fields needed by downstream units.
  // - Carry legality and first-micro-op decisions from decode.
  // - Advertise resource usage for status, assertions and debug inspection.
  typedef struct packed {
    logic [15:0] opcode;       // Original instruction word.
    logic [3:0]  opcode_class; // High opcode nibble.
    logic [3:0]  x;            // Vx register index.
    logic [3:0]  y;            // Vy register index.
    logic [3:0]  n;            // Low immediate nibble.
    logic [7:0]  kk;           // Low immediate byte.
    logic [11:0] nnn;          // Low address/immediate field.
    chip8_op_t   op;           // Decoded architectural operation.
    chip8_uop_t  first_uop;    // First core phase required by this opcode.
    logic        legal;        // Decode legality after subopcode checks.
    logic        writes_vx;    // Instruction writes Vx.
    logic        writes_vf;    // Instruction writes VF flag.
    logic        uses_memory;  // Instruction touches RAM/font/ROM paths.
    logic        uses_display; // Instruction touches framebuffer/display.
    logic        uses_timer;   // Instruction reads or writes timers.
    logic        uses_keypad;  // Instruction reads keypad state.
  } chip8_decoded_t;
endpackage

`default_nettype wire

// EOF

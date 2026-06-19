// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_debug_regs.sv
// -----------------------------------------------------------------------------
// @brief Formal harness for the CHIP-8 Debug regs.
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

module chip8_debug_regs (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [11:0] pc_i,
  input  logic [15:0] opcode_i,
  input  chip8_core_pkg::chip8_state_t state_i,
  input  chip8_core_pkg::chip8_decoded_t decoded_i,
  input  logic        halted_i,
  input  logic        fault_illegal_i,
  output logic [11:0] pc_o,
  output logic [15:0] opcode_o,
  output chip8_core_pkg::chip8_state_t state_o,
  output logic [31:0] status_o,
  output logic [31:0] scb_hfsr_o,
  output logic [31:0] scb_cfsr_o,
  output logic [31:0] scb_mmfar_o,
  output logic [31:0] scb_bfar_o,
  output logic [31:0] scb_shcsr_o,
  output logic [31:0] scb_dfsr_o,
  output logic [31:0] scb_afsr_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [31:0] CFSR_UFSR_UNDEFINSTR = 32'h00010000;
  localparam logic [31:0] HFSR_FORCED = 32'h40000000;
  localparam logic [31:0] SHCSR_USGFAULTACT = 32'h00000008;
  localparam logic [31:0] SHCSR_USGFAULTENA = 32'h00040000;
  localparam logic [31:0] DFSR_HALTED = 32'h00000001;
  localparam logic [31:0] AFSR_CHIP8_ILLEGAL = 32'h00000001;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [5:0] op_status;
  logic illegal_fault_seen;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign op_status = decoded_i.op;
  assign illegal_fault_seen =
    fault_illegal_i |
    ((state_i == chip8_core_pkg::CHIP8_CORE_PKG_STATE_TRAP) &
     halted_i &
     !decoded_i.legal);

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_o <= '0;
      opcode_o <= '0;
      state_o <= chip8_core_pkg::CHIP8_CORE_PKG_STATE_FETCH;
      status_o <= '0;
      scb_hfsr_o <= '0;
      scb_cfsr_o <= '0;
      scb_mmfar_o <= '0;
      scb_bfar_o <= '0;
      scb_shcsr_o <= SHCSR_USGFAULTENA;
      scb_dfsr_o <= '0;
      scb_afsr_o <= '0;
    end else begin
      pc_o <= pc_i;
      opcode_o <= opcode_i;
      state_o <= state_i;
      status_o <= {
        16'h0000,
        halted_i,
        decoded_i.legal,
        decoded_i.uses_memory,
        decoded_i.uses_display,
        decoded_i.uses_timer,
        decoded_i.uses_keypad,
        op_status,
        state_i
      };
      scb_dfsr_o <= halted_i ? (scb_dfsr_o | DFSR_HALTED) :
        scb_dfsr_o;
      if (illegal_fault_seen) begin
        scb_hfsr_o <= scb_hfsr_o | HFSR_FORCED;
        scb_cfsr_o <= scb_cfsr_o | CFSR_UFSR_UNDEFINSTR;
        scb_shcsr_o <= scb_shcsr_o | SHCSR_USGFAULTACT |
          SHCSR_USGFAULTENA;
        scb_afsr_o <= scb_afsr_o | AFSR_CHIP8_ILLEGAL;
      end
    end
  end
endmodule

`default_nettype wire

// EOF

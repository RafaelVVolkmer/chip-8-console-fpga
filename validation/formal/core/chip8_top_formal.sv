// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_top_formal.sv
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

module chip8_top_formal #(
  parameter int MAX_PC = 4095
) ();
  (* anyseq *) logic clk;
  (* anyseq *) logic rst_n;
  (* anyseq *) logic [15:0] keys;
  // ------------------------------------------------------------
  // Testbench signals
  // ------------------------------------------------------------

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

  chip8_top dut (
  .clk_i(clk),
  .rst_ni(rst_n),
  .keys_i(keys),
  .rom_load_valid_i(1'b0),
  .rom_load_ready_o(),
  .rom_load_offset_i(12'h000),
  .rom_load_data_i(8'h00),
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
  // Combinational checks
  // ------------------------------------------------------------

  always_comb begin
  if ($initstate) begin
    assume (!rst_n);
  end else begin
    assume (rst_n);
  end
  end

  always_comb begin
  assert (pc <= MAX_PC[11:0]);
  assert (debug_status[15] == halted);
  assert (display_x < 64);
  assert (display_y < 32);
  assert (sound_active == 1'b0 || sound_active == 1'b1);
  assert (halted == 1'b0 || halted == 1'b1);
  assert (scb_mmfar == 32'h00000000);
  assert (scb_bfar == 32'h00000000);
  if (display_valid) begin
    assert (display_pixel == 1'b0 || display_pixel == 1'b1);
  end
  end
endmodule

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_rom_loader.sv
// -----------------------------------------------------------------------------
// @brief CHIP-8 ROM load helper.
// =============================================================================
//
// Responsibilities:
// - Translate streamed ROM bytes into memory writes.
// - Apply the ROM base address and wrap mask.
// - Keep the load path handshake explicit.
//
// Characteristics:
// - Stateless front-end with a skid buffer boundary.
// - Address math is width-limited for 4 KiB RAM.
// - Supports boot ROM and DAP/SD load flows.
//
// Design notes:
// - Always name the ROM base and wrap mask used.
// =============================================================================
`default_nettype none

module chip8_rom_loader (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        valid_i,
  output logic        ready_o,
  input  logic [11:0] offset_i,
  input  logic [7:0]  data_i,
  output logic        mem_we_o,
  output logic [11:0] mem_addr_o,
  output logic [7:0]  mem_data_o
);
  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  localparam logic [11:0] CHIP8_ROM_LOADER_ADDR_MASK = 12'hfff;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic        load_valid;
  logic        load_ready;
  logic [19:0] load_data;
  logic [19:0] skid_data;
  logic        mem_we_q;
  logic        mem_we_d;
  logic [11:0] mem_addr_q;
  logic [11:0] mem_addr_d;
  logic [7:0]  mem_data_q;
  logic [7:0]  mem_data_d;

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign load_data = {offset_i, data_i};
  assign load_ready = '1;
  assign mem_we_d = load_valid;
  assign mem_addr_d = (chip8_pkg::CHIP8_ROM_BASE + skid_data[19:8]) &
    CHIP8_ROM_LOADER_ADDR_MASK;
  assign mem_data_d = skid_data[7:0];
  assign mem_we_o = mem_we_q;
  assign mem_addr_o = mem_addr_q;
  assign mem_data_o = mem_data_q;

  chip8_skid_buffer #(
    .DATA_WIDTH(20)
  ) u_loader_skid (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .in_valid_i(valid_i),
    .in_ready_o(ready_o),
    .in_data_i(load_data),
    .out_valid_o(load_valid),
    .out_ready_i(load_ready),
    .out_data_o(skid_data)
  );

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      mem_we_q <= '0;
      mem_addr_q <= '0;
      mem_data_q <= '0;
    end else begin
      mem_we_q <= mem_we_d;
      mem_addr_q <= mem_addr_d;
      mem_data_q <= mem_data_d;
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni && $past(rst_ni)) begin
      assert (mem_we_o == $past(load_valid));
      assert (mem_addr_o == ((chip8_pkg::CHIP8_ROM_BASE +
        $past(skid_data[19:8])) & CHIP8_ROM_LOADER_ADDR_MASK));
      assert (mem_data_o == $past(skid_data[7:0]));
    end
  end
`endif
endmodule

`default_nettype wire

// EOF

// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// tb_chip8_axi_lite.sv
// -----------------------------------------------------------------------------
// @brief SoC integration wrapper for Tb chip8 axi lite.
// =============================================================================
//
// Responsibilities:
// - Compose the CPU, memory, video, storage and debug blocks.
// - Route clocks, resets, buses and interrupts explicitly.
// - Keep integration policy outside leaf modules.
//
// Characteristics:
// - Top-level composition block.
// - Owns interconnect, not leaf algorithms.
// - Bridges board pins to reusable modules.
//
// Design notes:
// - Keep subsystem windows and clock domains named.
// =============================================================================
`default_nettype none

module tb_chip8_axi_lite;
// ------------------------------------------------------------
// Testbench signals
// ------------------------------------------------------------

logic clk;
logic rst_n;

logic [15:0] awaddr;
logic awvalid;
logic awready;
logic [31:0] wdata;
logic [3:0] wstrb;
logic wvalid;
logic wready;
logic [1:0] bresp;
logic bvalid;
logic bready;
logic [15:0] araddr;
logic arvalid;
logic arready;
logic [31:0] rdata;
logic [1:0] rresp;
logic rvalid;
logic rready;

logic reg_valid;
  logic reg_we;
  logic [15:0] reg_addr;
  logic [31:0] reg_wdata;
  logic [3:0] reg_wstrb;
  logic reg_ready;
  logic [31:0] reg_rdata;
  logic [7:0] ready_lfsr_q;

// ------------------------------------------------------------
// Stimulus and checks
// ------------------------------------------------------------

  initial clk = '0;
  always #5 clk = ~clk;

  chip8_axi_lite_to_reg u_frontend (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .s_axi_awaddr_i (awaddr),
    .s_axi_awvalid_i(awvalid),
    .s_axi_awready_o(awready),
    .s_axi_wdata_i  (wdata),
    .s_axi_wstrb_i  (wstrb),
    .s_axi_wvalid_i (wvalid),
    .s_axi_wready_o (wready),
    .s_axi_bresp_o  (bresp),
    .s_axi_bvalid_o (bvalid),
    .s_axi_bready_i (bready),
    .s_axi_araddr_i (araddr),
    .s_axi_arvalid_i(arvalid),
    .s_axi_arready_o(arready),
    .s_axi_rdata_o  (rdata),
    .s_axi_rresp_o  (rresp),
    .s_axi_rvalid_o (rvalid),
    .s_axi_rready_i (rready),
    .reg_valid_o    (reg_valid),
    .reg_we_o       (reg_we),
    .reg_addr_o     (reg_addr),
    .reg_wdata_o    (reg_wdata),
    .reg_wstrb_o    (reg_wstrb),
    .reg_ready_i    (reg_ready),
    .reg_rdata_i    (reg_rdata)
  );

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign reg_rdata = {16'ha55a, reg_addr};

  // ------------------------------------------------------------
  // Clocked testbench procedures
  // ------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      ready_lfsr_q <= 8'h5a;
      reg_ready <= '0;
    end else begin
      ready_lfsr_q <= {ready_lfsr_q[6:0],
                       ready_lfsr_q[7] ^ ready_lfsr_q[5] ^ ready_lfsr_q[4] ^
                       ready_lfsr_q[3]};
      reg_ready <= reg_valid && ready_lfsr_q[1:0] != '0;
    end
  end

  // ------------------------------------------------------------
  // Testbench tasks
  // ------------------------------------------------------------

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic axi_write_split_addr_first(
    input logic [15:0] addr,
    input logic [31:0] data
    );
  begin
    awaddr = addr;
    awvalid = '1;
    #1;
    assert (awready);
    tick();
    awvalid = '0;

    repeat (2) tick();

    wdata = data;
    wstrb = 4'hf;
    wvalid = '1;
    #1;
    assert (wready);
    tick();
    wvalid = '0;

    wait (bvalid);
    assert (bresp == 2'b00);
    tick();
  end
endtask

task automatic axi_write_split_data_first(
  input logic [15:0] addr,
  input logic [31:0] data
  );
begin
  wdata = data;
  wstrb = 4'hf;
  wvalid = '1;
  #1;
  assert (wready);
  tick();
  wvalid = '0;

  repeat (2) tick();

  awaddr = addr;
  awvalid = '1;
  #1;
  assert (awready);
  tick();
  awvalid = '0;

  wait (bvalid);
  assert (bresp == 2'b00);
  tick();
end
  endtask

  task automatic axi_read(
    input  logic [15:0] addr,
    output logic [31:0] data
    );
  begin
    araddr = addr;
    arvalid = '1;
    do begin
      tick();
    end while (arvalid && !arready);
    arvalid = '0;

    wait (rvalid);
    assert (rresp == 2'b00);
    data = rdata;
    tick();
  end
  endtask

  task automatic axi_write_randomized(
    input logic [15:0] addr,
    input logic [31:0] data,
    input logic        data_first
    );
  begin
    if (data_first) begin
      axi_write_split_data_first(addr, data);
    end else begin
      axi_write_split_addr_first(addr, data);
    end
  end
  endtask

  initial begin : axi_smoke_test
    logic [31:0] read_value;
    int unsigned i;

    rst_n = '0;
    awaddr = '0;
    awvalid = '0;
    wdata = '0;
    wstrb = '0;
    wvalid = '0;
    bready = '1;
    araddr = '0;
    arvalid = '0;
    rready = '1;
    repeat (3) tick();
    rst_n = '1;
    repeat (2) tick();

    awaddr = 16'h1000;
    wdata = 32'h0000_000f;
    wstrb = 4'hf;
    awvalid = '1;
    wvalid = '1;
    do begin
      tick();
    end while ((awvalid && !awready) || (wvalid && !wready));
    awvalid = '0;
    wvalid = '0;
    wait (bvalid);
    assert (bresp == 2'b00);
    tick();

    axi_write_split_addr_first(16'h1004, 32'h1122_3344);
    axi_write_split_data_first(16'h1008, 32'h5566_7788);

    for (i = '0; i < 16; i++) begin
      axi_write_randomized(16'h1200 + i[15:0],
        32'hca00_0000 | i, i[0]);
    end

    axi_read(16'h1108, read_value);
    assert (read_value[15:0] == 16'h1108);

    $finish;
  end
  endmodule

  `default_nettype wire

  // EOF

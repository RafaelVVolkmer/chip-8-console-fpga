// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_axi_lite_to_reg.sv
// -----------------------------------------------------------------------------
// @brief AXI-Lite to register bridge.
// =============================================================================
//
// Responsibilities:
// - Translate AXI-Lite accesses into local register reads and writes.
// - Map byte strobes and read data cleanly.
// - Keep bus timing and register timing separate.
//
// Characteristics:
// - Bus adapter, not a storage element.
// - Maintains a strict register-side contract.
// - Used by the SoC wrappers and peripherals.
//
// Design notes:
// - Keep each AXI channel handshake explicit.
// =============================================================================
`default_nettype none

module chip8_axi_lite_to_reg #(
  parameter int ADDR_WIDTH = chip8_axi_pkg::AXI_ADDR_WIDTH,
  parameter int DATA_WIDTH = chip8_axi_pkg::AXI_DATA_WIDTH,
  parameter int STRB_WIDTH = chip8_axi_pkg::AXI_STRB_WIDTH
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,

  input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr_i,
  input  logic                    s_axi_awvalid_i,
  output logic                    s_axi_awready_o,
  input  logic [DATA_WIDTH-1:0]   s_axi_wdata_i,
  input  logic [STRB_WIDTH-1:0]   s_axi_wstrb_i,
  input  logic                    s_axi_wvalid_i,
  output logic                    s_axi_wready_o,
  output logic [1:0]              s_axi_bresp_o,
  output logic                    s_axi_bvalid_o,
  input  logic                    s_axi_bready_i,

  input  logic [ADDR_WIDTH-1:0]   s_axi_araddr_i,
  input  logic                    s_axi_arvalid_i,
  output logic                    s_axi_arready_o,
  output logic [DATA_WIDTH-1:0]   s_axi_rdata_o,
  output logic [1:0]              s_axi_rresp_o,
  output logic                    s_axi_rvalid_o,
  input  logic                    s_axi_rready_i,

  output logic                    reg_valid_o,
  output logic                    reg_we_o,
  output logic [ADDR_WIDTH-1:0]   reg_addr_o,
  output logic [DATA_WIDTH-1:0]   reg_wdata_o,
  output logic [STRB_WIDTH-1:0]   reg_wstrb_o,
  input  logic                    reg_ready_i,
  input  logic [DATA_WIDTH-1:0]   reg_rdata_i
);
  // ------------------------------------------------------------
  // Type declarations
  // ------------------------------------------------------------

  // AXI-lite transaction bridge state.
  //
  // Responsibilities:
  // - Hold partial AW/W channel handshakes until a complete write exists.
  // - Wait for the internal register target to acknowledge access.
  // - Emit one AXI response per accepted transaction.
  typedef enum logic [1:0] {
    USED_STATE_IDLE,
    USED_STATE_WAIT_REG,
    USED_STATE_RESP
  } state_e;

  state_e state_q;
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic   pending_we_q;
  logic   aw_seen_q;
  logic   w_seen_q;
  logic [ADDR_WIDTH-1:0] awaddr_q;
  logic [DATA_WIDTH-1:0] wdata_q;
  logic [STRB_WIDTH-1:0] wstrb_q;
  logic                  aw_valid;
  logic                  aw_ready;
  logic [ADDR_WIDTH-1:0] awaddr;
  logic                  w_valid;
  logic                  w_ready;
  logic [DATA_WIDTH-1:0] wdata;
  logic [STRB_WIDTH-1:0] wstrb;
  logic                  ar_valid;
  logic                  ar_ready;
  logic [ADDR_WIDTH-1:0] araddr;

  // ------------------------------------------------------------
  // Submodule instances
  // ------------------------------------------------------------

  chip8_skid_buffer #(
    .DATA_WIDTH(ADDR_WIDTH)
  ) u_aw_skid (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .in_valid_i(s_axi_awvalid_i),
    .in_ready_o(s_axi_awready_o),
    .in_data_i(s_axi_awaddr_i),
    .out_valid_o(aw_valid),
    .out_ready_i(aw_ready),
    .out_data_o(awaddr)
  );

  chip8_skid_buffer #(
    .DATA_WIDTH(DATA_WIDTH + STRB_WIDTH)
  ) u_w_skid (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .in_valid_i(s_axi_wvalid_i),
    .in_ready_o(s_axi_wready_o),
    .in_data_i({s_axi_wstrb_i, s_axi_wdata_i}),
    .out_valid_o(w_valid),
    .out_ready_i(w_ready),
    .out_data_o({wstrb, wdata})
  );

  chip8_skid_buffer #(
    .DATA_WIDTH(ADDR_WIDTH)
  ) u_ar_skid (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .in_valid_i(s_axi_arvalid_i),
    .in_ready_o(s_axi_arready_o),
    .in_data_i(s_axi_araddr_i),
    .out_valid_o(ar_valid),
    .out_ready_i(ar_ready),
    .out_data_o(araddr)
  );

  // ------------------------------------------------------------
  // Continuous assignments
  // ------------------------------------------------------------

  assign aw_ready = (state_q == USED_STATE_IDLE) && !aw_seen_q;
  assign w_ready  = (state_q == USED_STATE_IDLE) && !w_seen_q;
  assign ar_ready = (state_q == USED_STATE_IDLE) && !aw_seen_q &&
    !w_seen_q && !aw_valid && !w_valid;
  assign s_axi_bresp_o   = '0;
  assign s_axi_rresp_o   = '0;

  // AW and W are captured independently and joined before the register
  // request is emitted. This keeps AXI-lite ordering deterministic while
  // preserving channel decoupling at the fabric edge.
  // Ref: Dally, virtual-channel flow control, ACM/IEEE ISCA, 1990.

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk_i) begin : axi_frontend_state_ff
    if (!rst_ni) begin
      state_q        <= USED_STATE_IDLE;
      pending_we_q   <= '0;
      aw_seen_q      <= '0;
      w_seen_q       <= '0;
      awaddr_q       <= '0;
      wdata_q        <= '0;
      wstrb_q        <= '0;
      reg_valid_o    <= '0;
      reg_we_o       <= '0;
      reg_addr_o     <= '0;
      reg_wdata_o    <= '0;
      reg_wstrb_o    <= '0;
      s_axi_bvalid_o <= '0;
      s_axi_rvalid_o <= '0;
      s_axi_rdata_o  <= '0;
    end else begin
      unique case (state_q)
        USED_STATE_IDLE: begin
          reg_valid_o <= '0;

          if (aw_ready && aw_valid) begin
            aw_seen_q <= '1;
            awaddr_q  <= awaddr;
          end

          if (w_ready && w_valid) begin
            w_seen_q <= '1;
            wdata_q  <= wdata;
            wstrb_q  <= wstrb;
          end

          if ((aw_seen_q || (aw_ready && aw_valid)) &&
            (w_seen_q || (w_ready && w_valid))) begin
            reg_valid_o  <= '1;
            reg_we_o     <= '1;
            reg_addr_o   <= aw_seen_q ? awaddr_q :
              awaddr;
            reg_wdata_o  <= w_seen_q ? wdata_q : wdata;
            reg_wstrb_o  <= w_seen_q ? wstrb_q : wstrb;
            pending_we_q <= '1;
            state_q      <= USED_STATE_WAIT_REG;
          end else if (ar_ready && ar_valid) begin
            reg_valid_o  <= '1;
            reg_we_o     <= '0;
            reg_addr_o   <= araddr;
            reg_wdata_o  <= '0;
            reg_wstrb_o  <= '0;
            pending_we_q <= '0;
            state_q      <= USED_STATE_WAIT_REG;
          end
        end

        USED_STATE_WAIT_REG: begin
          reg_valid_o <= '1;
          if (reg_ready_i) begin
            reg_valid_o <= '0;
            if (pending_we_q) begin
              s_axi_bvalid_o <= '1;
            end else begin
              s_axi_rvalid_o <= '1;
              s_axi_rdata_o  <= reg_rdata_i;
            end
            state_q <= USED_STATE_RESP;
          end
        end

        USED_STATE_RESP: begin
          if (pending_we_q) begin
            if (s_axi_bready_i) begin
              s_axi_bvalid_o <= '0;
              aw_seen_q      <= '0;
              w_seen_q       <= '0;
              state_q        <= USED_STATE_IDLE;
            end
          end else if (s_axi_rready_i) begin
            s_axi_rvalid_o <= '0;
            aw_seen_q      <= '0;
            w_seen_q       <= '0;
            state_q        <= USED_STATE_IDLE;
          end
        end

        default: begin
          reg_valid_o <= '0;
          aw_seen_q   <= '0;
          w_seen_q    <= '0;
          state_q     <= USED_STATE_IDLE;
        end
      endcase
    end
  end

  // ------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------

`ifdef FORMAL
  always_ff @(posedge clk_i) begin
    if (rst_ni && $past(rst_ni)) begin
      if ($past(reg_valid_o && !reg_ready_i)) begin
        assert (reg_valid_o);
        assert (reg_we_o == $past(reg_we_o));
        assert (reg_addr_o == $past(reg_addr_o));
        assert (reg_wdata_o == $past(reg_wdata_o));
        assert (reg_wstrb_o == $past(reg_wstrb_o));
      end

      assert (
        (state_q == USED_STATE_IDLE) ||
        (state_q == USED_STATE_WAIT_REG) ||
        (state_q == USED_STATE_RESP)
      );
      assert (
        !s_axi_bvalid_o ||
        ((state_q == USED_STATE_RESP) && pending_we_q)
      );
      assert (
        !s_axi_rvalid_o ||
        ((state_q == USED_STATE_RESP) && !pending_we_q)
      );
      assert (!(s_axi_bvalid_o && s_axi_rvalid_o));
      assert (!(aw_seen_q && aw_ready));
      assert (!(w_seen_q && w_ready));
    end
  end
`endif
endmodule

`default_nettype wire

// EOF

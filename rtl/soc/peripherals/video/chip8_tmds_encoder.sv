// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

// =============================================================================
// chip8_tmds_encoder.sv
// -----------------------------------------------------------------------------
// @brief TMDS encoder.
// =============================================================================
//
// Responsibilities:
// - Encode pixel data into TMDS symbols.
// - Support HDMI data and control periods.
// - Keep the symbol transition rules visible.
//
// Characteristics:
// - Pure encoder logic.
// - No platform timing or serializer state.
// - Used by the HDMI backend only.
//
// Design notes:
// - Keep control and data symbol paths explicit.
// =============================================================================
`default_nettype none

module chip8_tmds_encoder (
  input  logic       de_i,
  input  logic [1:0] ctrl_i,
  input  logic [7:0] data_i,
  output logic [9:0] encoded_o
);
  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------

  logic [3:0] ones;
  logic [8:0] q_m;

  // ------------------------------------------------------------
  // Combinational logic
  // ------------------------------------------------------------

  always_comb begin : tmds_encode_comb
    ones = {3'b000, data_i[0]} + {3'b000, data_i[1]} + {3'b000,
      data_i[2]} + {3'b000, data_i[3]}
       + {3'b000, data_i[4]} + {3'b000, data_i[5]} + {3'b000,
         data_i[6]} + {3'b000, data_i[7]};

    q_m[0] = data_i[0];
    q_m[1] = q_m[0] ^ data_i[1];
    q_m[2] = q_m[1] ^ data_i[2];
    q_m[3] = q_m[2] ^ data_i[3];
    q_m[4] = q_m[3] ^ data_i[4];
    q_m[5] = q_m[4] ^ data_i[5];
    q_m[6] = q_m[5] ^ data_i[6];
    q_m[7] = q_m[6] ^ data_i[7];
    q_m[8] = (ones <= 4'd4);

    if (!de_i) begin
      unique case (ctrl_i)
        2'b00: encoded_o = 10'b1101010100;
        2'b01: encoded_o = 10'b0010101011;
        2'b10: encoded_o = 10'b0101010100;
        default: encoded_o = 10'b1010101011;
      endcase
    end else begin
      encoded_o = {~q_m[8], q_m[8], q_m[7:0]};
    end
  end
endmodule

`default_nettype wire

// EOF

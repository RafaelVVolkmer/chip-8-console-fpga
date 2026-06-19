# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

create_clock \
  -name clk_50mhz_i \
  -period 20.000 \
  [get_ports {clk_50mhz_i}]

derive_pll_clocks
derive_clock_uncertainty

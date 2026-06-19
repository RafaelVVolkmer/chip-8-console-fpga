# SPDX-License-Identifier: GPL-3.0-only
# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

# Gowin EDA project script hook for Tang Nano 9K.
# Pin assignment must be completed in constraints/gowin/tang_nano_9k_*.cst for
# the selected backend.
set_device GW1NR-LV9QN88PC6/I5
add_file -type verilog [glob rtl/core/chip8/pkg/*.sv]
add_file -type verilog [glob rtl/core/chip8/cpu/*.sv]
add_file -type verilog [glob rtl/core/chip8/memory/*.sv]
add_file -type verilog [glob rtl/core/chip8/video/*.sv]
add_file -type verilog [glob rtl/core/chip8/timers/*.sv]
add_file -type verilog [glob rtl/core/chip8/input/*.sv]
add_file -type verilog [glob rtl/core/chip8/bus/*.sv]
add_file -type verilog [glob rtl/soc/bus/*.sv]
add_file -type verilog [glob rtl/soc/debug/*.sv]
add_file -type verilog [glob rtl/soc/storage/*.sv]
add_file -type verilog [glob rtl/soc/dma/*.sv]
add_file -type verilog [glob rtl/soc/irq/*.sv]
add_file -type verilog [glob rtl/soc/peripherals/keypad/*.sv]
add_file -type verilog [glob rtl/soc/peripherals/video/*.sv]
add_file -type verilog rtl/soc/chip8_native_soc.sv
add_file -type verilog rtl/soc/chip8_axi_soc.sv
add_file -type verilog [glob rtl/boards/common/*.sv]
add_file -type verilog [glob rtl/boards/tang_nano_9k/*.sv]
set_option -top_module tang_nano_9k_top
run all

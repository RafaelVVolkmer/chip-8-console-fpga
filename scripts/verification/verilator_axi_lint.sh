#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

warn_args=()

if [ -n "${VERILATOR_WARN_FLAGS:-}" ]; then
    read -r -a warn_args <<<"${VERILATOR_WARN_FLAGS}"
else
    warn_args=(
        -Wno-DECLFILENAME
        -Wno-PINCONNECTEMPTY
        -Wno-UNUSEDSIGNAL
        -Wno-UNUSEDPARAM
        -Wno-UNSIGNED
        -Wno-SYNCASYNCNET
        -Wno-CMPCONST
    )
fi

run_lint() {
    top="$1"
    shift
    verilator \
        --lint-only \
        -Wall \
        "${warn_args[@]}" \
        -Irtl \
        --top-module "${top}" \
        -f files.f \
        "$@"
}

run_lint chip8_soc_axi
run_lint tang_nano_9k_top
run_lint custom_usb_fpga_top
run_lint cyclone_v_top
run_lint artix_a7_top
run_lint tb_chip8_axi_lite \
    --timing \
    validation/simulation/soc/axi/tb_chip8_axi_lite.sv
run_lint tb_chip8_keypad_remote_core \
    --timing \
    validation/simulation/soc/keypad/tb_chip8_keypad_remote_core.sv
run_lint tb_chip8_video_remote_core \
    --timing \
    validation/simulation/soc/video/tb_chip8_video_remote_core.sv
run_lint tb_tang_nano_9k_top \
    --timing \
    validation/simulation/boards/tang_nano_9k/tb_tang_nano_9k_top.sv
run_lint tb_chip8_boot_pipeline \
    --timing \
    validation/simulation/soc/axi/tb_chip8_boot_pipeline.sv

# EOF

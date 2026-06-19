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
        --timing \
        -Wall \
        "${warn_args[@]}" \
        -Irtl \
        --top-module "${top}" \
        -f files.f \
        "$@"
}

run_lint chip8_top
run_lint tb_chip8_top validation/simulation/core/tb_chip8_top.sv
run_lint tb_chip8_components \
    validation/simulation/core/tb_chip8_components.sv
run_lint tb_chip8_blocks_exhaustive \
    validation/simulation/core/tb_chip8_blocks_exhaustive.sv

# EOF

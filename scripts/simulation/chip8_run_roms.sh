#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

rom_dir="${CHIP8_ROM_DIR:-validation/programs/chip8/roms}"
mem_dir="${CHIP8_ROM_MEM_DIR:-generated/chip8/roms}"
max_cycles="${CHIP8_ROM_STEPS:-2500}"
coverage="${COVERAGE:-0}"
mdir="${MDIR:-obj/tb_chip8_roms}"
coverage_args=()
runtime_cov=()
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

mkdir -p "${mdir}" "${mem_dir}" reports reports/coverage

if [ "${coverage}" = "1" ]; then
    coverage_args=(--coverage)
    runtime_cov=(
        +verilator+coverage+file+reports/coverage/tb_chip8_roms.dat
    )
fi

verilator \
    --binary \
    --timing \
    "${coverage_args[@]}" \
    -Wall \
    "${warn_args[@]}" \
    -Irtl \
    --Mdir "${mdir}" \
    --top-module tb_chip8_top \
    -f files.f \
    validation/simulation/core/tb_chip8_top.sv

count=0
for rom in "${rom_dir}"/*; do
    [ -f "${rom}" ] || continue
    name="$(basename "${rom}")"
    mem="${mem_dir}/${name}.mem"
    (
        cd validation/rust
        cargo run -q \
            -p chip8-model \
            --bin gen-chip8-rom \
            -- "../../${rom}" "../../${mem}"
    )
    run_cov=("${runtime_cov[@]}")
    if [ "${coverage}" = "1" ]; then
        safe_name="$(printf '%s' "${name}" | tr -c 'A-Za-z0-9_.-' '_')"
        run_cov=(
            "+verilator+coverage+file+reports/coverage/rom_${safe_name}.dat"
        )
    fi
    "./${mdir}/Vtb_chip8_top" \
        "+CHIP8_ROM_MEM=${mem}" \
        +GENERIC_ROM \
        "+MAX_CYCLES=${max_cycles}" \
        "${run_cov[@]}"
    count=$((count + 1))
done

echo "CHIP-8 ROM stress completed: ${count} ROMs"
echo "Cycles per ROM: ${max_cycles}"

# EOF

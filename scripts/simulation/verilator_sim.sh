#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

top="${TOP:-tb_chip8_top}"
trace="${TRACE:-0}"
coverage="${COVERAGE:-0}"
mdir="${MDIR:-obj/${top}}"
files="${FILES:-files.f}"
trace_args=()
coverage_args=()
runtime_args=()
warn_args=()
sim_root="validation/simulation"

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

if [ -n "${SIM_ARGS:-}" ]; then
    read -r -a runtime_args <<<"${SIM_ARGS}"
fi

if [ "${trace}" = "1" ]; then
    trace_args=(--trace)
fi

if [ "${coverage}" = "1" ]; then
    coverage_args=(--coverage)
    mkdir -p reports/coverage
    runtime_args+=(
        "+verilator+coverage+file+reports/coverage/${top}.dat"
    )
fi

case "${top}" in
    tb_chip8_top)
        tb_file="${sim_root}/core/tb_chip8_top.sv"
        ;;
    tb_chip8_components)
        tb_file="${sim_root}/core/tb_chip8_components.sv"
        ;;
    tb_chip8_blocks_exhaustive)
        tb_file="${sim_root}/core/tb_chip8_blocks_exhaustive.sv"
        ;;
    tb_chip8_axi_lite)
        tb_file="${sim_root}/soc/axi/tb_chip8_axi_lite.sv"
        ;;
    tb_chip8_keypad_remote_core)
        tb_file="${sim_root}/soc/keypad/tb_chip8_keypad_remote_core.sv"
        ;;
    tb_chip8_video_remote_core)
        tb_file="${sim_root}/soc/video/tb_chip8_video_remote_core.sv"
        ;;
    tb_tang_nano_9k_top)
        tb_file="${sim_root}/boards/tang_nano_9k/tb_tang_nano_9k_top.sv"
        ;;
    tb_chip8_boot_pipeline)
        tb_file="${sim_root}/soc/axi/tb_chip8_boot_pipeline.sv"
        ;;
    tb_chip8_dap_protocol)
        tb_file="${sim_root}/soc/debug/tb_chip8_dap_protocol.sv"
        ;;
    *)
        echo "unknown TOP=${top}" >&2
        exit 2
        ;;
esac

mkdir -p "${mdir}"

verilator \
    --binary \
    --timing \
    "${trace_args[@]}" \
    "${coverage_args[@]}" \
    -Wall \
    "${warn_args[@]}" \
    -Irtl \
    --Mdir "${mdir}" \
    --top-module "${top}" \
    -f "${files}" \
    "${tb_file}"

"./${mdir}/V${top}" "${runtime_args[@]}"

# EOF

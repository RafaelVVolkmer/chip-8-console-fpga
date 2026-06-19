#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

board="${BOARD:-}"
port="${PORT:-/dev/ttyACM1}"
baud="${BAUD:-115200}"
rom="${CHIP8_ROM:-validation/programs/chip8/smoke.ch8}"
program="${PROGRAM:-0}"
dap="${DAP:-0}"

case "${board}" in
    tang_nano_9k)
        loader="${BOARD_LOADER:-tangnano9k}"
        bitstream="${BITSTREAM:-build/tang_nano_9k/impl/pnr/project.fs}"
        ;;
    artix_a7)
        loader="${BOARD_LOADER:-arty_a7_35t}"
        bitstream="${BITSTREAM:-build/artix_a7_top/artix_a7_top.bit}"
        ;;
    cyclone_v)
        loader="${BOARD_LOADER:-de10nano}"
        bitstream="${BITSTREAM:-build/cyclone_v_top_quartus/output_files/cyclone_v_top.sof}"
        ;;
    *)
        echo "Unsupported BOARD=${board}. Use tang_nano_9k, artix_a7, or cyclone_v." >&2
        exit 2
        ;;
esac

report="${REPORT:-reports/board/${board}_smoke.json}"
mkdir -p "$(dirname "${report}")"

if [ ! -f "${rom}" ]; then
    echo "missing ROM: ${rom}" >&2
    exit 2
fi

if [ "${program}" = "1" ]; then
    if [ ! -f "${bitstream}" ]; then
        echo "missing bitstream: ${bitstream}" >&2
        exit 2
    fi
    command -v openFPGALoader >/dev/null || {
        echo "openFPGALoader not found" >&2
        exit 127
    }
    openFPGALoader -b "${loader}" "${bitstream}"
fi

if [ "${dap}" = "1" ]; then
    bash scripts/programming/chip8_usb_dap.sh \
        --port "${port}" \
        --baud "${baud}" \
        id
    bash scripts/programming/chip8_usb_dap.sh \
        --port "${port}" \
        --baud "${baud}" \
        load-rom "${rom}"
fi

cat >"${report}" <<JSON
{
  "board": "${board}",
  "loader": "${loader}",
  "port": "${port}",
  "baud": ${baud},
  "bitstream": "${bitstream}",
  "rom": "${rom}",
  "programmed": "${program}",
  "dap": "${dap}",
  "status": "preflight_passed"
}
JSON

echo "${board} board smoke report written to ${report}"

# EOF

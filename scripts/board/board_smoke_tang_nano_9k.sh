#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

port="${PORT:-/dev/ttyACM1}"
baud="${BAUD:-115200}"
bitstream="${BITSTREAM:-build/tang_nano_9k/impl/pnr/project.fs}"
rom="${CHIP8_ROM:-validation/programs/chip8/smoke.ch8}"
report="${REPORT:-reports/board/tang_nano_9k_smoke.json}"
loader="${BOARD_LOADER:-tangnano9k}"

mkdir -p "$(dirname "${report}")"

if [ ! -f "${bitstream}" ]; then
    echo "missing bitstream: ${bitstream}" >&2
    exit 2
fi

if [ ! -f "${rom}" ]; then
    echo "missing ROM: ${rom}" >&2
    exit 2
fi

command -v openFPGALoader >/dev/null || {
    echo "openFPGALoader not found" >&2
    exit 127
}

bash scripts/programming/chip8_usb_dap.sh \
    --port "${port}" \
    --baud "${baud}" \
    id >/tmp/chip8_board_id_before.txt

openFPGALoader -b "${loader}" "${bitstream}"
sleep 2

bash scripts/programming/chip8_usb_dap.sh \
    --port "${port}" \
    --baud "${baud}" \
    id >/tmp/chip8_board_id_after.txt

bash scripts/programming/chip8_usb_dap.sh \
    --port "${port}" \
    --baud "${baud}" \
    load-rom "${rom}"

cat >"${report}" <<JSON
{
  "board": "tang_nano_9k",
  "port": "${port}",
  "baud": ${baud},
  "bitstream": "${bitstream}",
  "rom": "${rom}",
  "status": "rom_loaded"
}
JSON

echo "Tang Nano 9K board smoke report written to ${report}"

# EOF

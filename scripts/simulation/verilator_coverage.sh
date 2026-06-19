#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set -eu

mkdir -p reports/coverage reports/coverage/annotated
rm -f reports/coverage/*.dat reports/coverage/*.lcov

run_cov() {
    env COVERAGE=1 "$@" bash scripts/simulation/verilator_sim.sh
}

run_cov MDIR=obj/cov/tb_chip8_components TOP=tb_chip8_components
run_cov MDIR=obj/cov/tb_chip8_blocks_exhaustive TOP=tb_chip8_blocks_exhaustive
run_cov \
    MDIR=obj/cov/tb_chip8_top \
    TOP=tb_chip8_top \
    SIM_ARGS="+CHIP8_ROM_MEM=validation/programs/chip8/smoke.mem"
run_cov \
    MDIR=obj/cov/tb_chip8_axi_lite \
    TOP=tb_chip8_axi_lite
run_cov \
    MDIR=obj/cov/tb_chip8_keypad_remote_core \
    TOP=tb_chip8_keypad_remote_core
run_cov \
    MDIR=obj/cov/tb_chip8_video_remote_core \
    TOP=tb_chip8_video_remote_core
run_cov \
    MDIR=obj/cov/tb_tang_nano_9k_top \
    TOP=tb_tang_nano_9k_top

COVERAGE=1 \
    MDIR=obj/cov/tb_chip8_roms \
    CHIP8_ROM_DIR="${CHIP8_ROM_DIR:-validation/programs/chip8/roms}" \
    CHIP8_ROM_MEM_DIR="${CHIP8_ROM_MEM_DIR:-generated/chip8/roms}" \
    CHIP8_ROM_STEPS="${CHIP8_ROM_STEPS:-2500}" \
    bash scripts/simulation/chip8_run_roms.sh

if command -v verilator_coverage >/dev/null 2>&1; then
    verilator_coverage \
        --write-info reports/coverage/chip8.lcov \
        reports/coverage/*.dat
    verilator_coverage \
        --annotate reports/coverage/annotated \
        reports/coverage/*.dat \
        >/dev/null
    echo "Coverage reports generated under reports/coverage"
else
    echo "verilator_coverage not found" >&2
    echo "Raw coverage .dat files were generated" >&2
fi

# EOF

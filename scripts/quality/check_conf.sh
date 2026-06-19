#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer
# <rafael.v.volkmer@gmail.com>

set -euo pipefail

have_files() {
    [ "$#" -gt 0 ]
}

collect_files() {
    local pattern="$1"
    find . \
        \( -path './.git' \
        -o -path './build' \
        -o -path './generated' \
        -o -path './obj' \
        -o -path './reports' \
        -o -path './validation/rust/target' \
        -o -path './validation/formal/core/chip8_blocks' \
        -o -path './validation/formal/soc/axi/chip8_boot_pipeline' \
        -o -path './validation/formal/core/chip8_components' \
        -o -path './validation/formal/coverage/chip8_cover' \
        -o -path './validation/formal/protocol/chip8_protocol_blocks' \
        -o -path './validation/formal/soc/axi/chip8_soc_axi' \
        -o -path './validation/formal/soc/keypad/chip8_keypad' \
        -o -path './validation/formal/soc/video/chip8_video' \
        -o -path './validation/formal/core/chip8_top' \
        -o -path './validation/formal/boards/tang_nano_9k/tang_nano_9k' \
        \) -prune \
        -o -type f -name "${pattern}" -print | sort
}

lint_markdown() {
    local failures=0
    local file
    local last
    local first_heading

    for file in "$@"; do
        if grep -n '[[:blank:]]$' "${file}"; then
            failures=1
        fi
        if grep -n "$(printf '\t')" "${file}"; then
            failures=1
        fi

        first_heading="$(awk '
            /^#/ {
                print NR ":" $0
                exit
            }
        ' "${file}")"
        if [ -n "${first_heading}" ] &&
            ! printf '%s\n' "${first_heading}" | grep -Eq '^[0-9]+:#[^#]'; then
            printf '%s:%s: first heading should be H1\n' \
                "${file}" "${first_heading%%:*}" >&2
            failures=1
        fi

        last="$(tail -c 1 "${file}" 2>/dev/null || true)"
        if [ -n "${last}" ]; then
            printf '%s: missing final newline\n' "${file}" >&2
            failures=1
        fi
    done

    return "${failures}"
}

mapfile -t md_files < <(collect_files '*.md')
mapfile -t yml_files < <(collect_files '*.yml')
mapfile -t yaml_files < <(collect_files '*.yaml')
mapfile -t toml_files < <(collect_files '*.toml')
mapfile -t json_files < <(collect_files '*.json')
mapfile -t sh_files < <(collect_files '*.sh')

if have_files "${md_files[@]}"; then
    lint_markdown "${md_files[@]}"
fi

if have_files "${yml_files[@]}" || have_files "${yaml_files[@]}"; then
    yamllint "${yml_files[@]}" "${yaml_files[@]}"
fi

if have_files "${toml_files[@]}"; then
    taplo lint "${toml_files[@]}"
    taplo format --check "${toml_files[@]}"
fi

for json in "${json_files[@]}"; do
    jq empty "${json}"
done

if have_files "${sh_files[@]}"; then
    shellcheck "${sh_files[@]}"
    shfmt -d -i 4 -ci "${sh_files[@]}"
fi

#!/usr/bin/env sh
# SPDX-License-Identifier: GPL-3.0-only
# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer
# <rafael.v.volkmer@gmail.com>

set -eu

root="."
limit="80"
max_reports="200"

usage() {
    echo "usage: $0 [root] [--limit columns]" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --limit)
            [ "$#" -ge 2 ] || {
                usage
                exit 2
            }
            limit="$2"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            usage
            exit 2
            ;;
        *)
            root="$1"
            shift
            ;;
    esac
done

case "${limit}" in
    '' | *[!0-9]*)
        echo "invalid --limit: ${limit}" >&2
        exit 2
        ;;
esac

is_excluded() {
    path="$1"
    case "${path}" in
        ./.git | ./.git/* | ./build | ./build/* | ./generated | ./generated/*)
            return 0
            ;;
        ./.vscode-ctags)
            return 0
            ;;
        ./VerilogCodingStyle.md)
            return 0
            ;;
        ./obj | ./obj/* | ./obj_dir | ./obj_dir/* | ./obj_dir_* | \
            ./reports | ./reports/*)
            return 0
            ;;
        ./logs | ./logs/* | ./outputs | ./outputs/* | \
            ./coverage | ./coverage/*)
            return 0
            ;;
        ./validation/rust/target | ./validation/rust/target/*)
            return 0
            ;;
        */__pycache__ | */__pycache__/* | */.pytest_cache | \
            */.pytest_cache/* | */.mypy_cache | */.mypy_cache/* | \
            */.ruff_cache | */.ruff_cache/*)
            return 0
            ;;
        ./validation/formal/core/chip8_blocks | \
            ./validation/formal/core/chip8_blocks/*)
            return 0
            ;;
        ./validation/formal/soc/axi/chip8_boot_pipeline | \
            ./validation/formal/soc/axi/chip8_boot_pipeline/*)
            return 0
            ;;
        ./validation/formal/core/chip8_components | \
            ./validation/formal/core/chip8_components/*)
            return 0
            ;;
        ./validation/formal/coverage/chip8_cover | \
            ./validation/formal/coverage/chip8_cover/*)
            return 0
            ;;
        ./validation/formal/protocol/chip8_protocol_blocks | \
            ./validation/formal/protocol/chip8_protocol_blocks/*)
            return 0
            ;;
        ./validation/formal/soc/axi/chip8_soc_axi | \
            ./validation/formal/soc/axi/chip8_soc_axi/*)
            return 0
            ;;
        ./validation/formal/soc/keypad/chip8_keypad | \
            ./validation/formal/soc/keypad/chip8_keypad/*)
            return 0
            ;;
        ./validation/formal/soc/video/chip8_video | \
            ./validation/formal/soc/video/chip8_video/*)
            return 0
            ;;
        ./validation/formal/core/chip8_top | \
            ./validation/formal/core/chip8_top/*)
            return 0
            ;;
        ./validation/formal/boards/tang_nano_9k/tang_nano_9k | \
            ./validation/formal/boards/tang_nano_9k/tang_nano_9k/*)
            return 0
            ;;
        *.ch8 | *.gz | *.ico | *.jpg | *.png | *.sqlite | *.zip)
            return 0
            ;;
    esac
    return 1
}

is_text_file() {
    path="$1"
    [ -f "${path}" ] || return 1
    LC_ALL=C grep -Iq . "${path}" 2>/dev/null
}

reports=0

cd "${root}"

while IFS= read -r path; do
    is_excluded "${path}" && continue
    is_text_file "${path}" || continue

    awk -v limit="${limit}" -v file="${path#./}" '
        length($0) > limit {
            printf "%s:%d: %d columns\n", file, FNR, length($0)
        }
    ' "${path}" | while IFS= read -r line; do
        echo "${line}"
        reports=$((reports + 1))
        if [ "${reports}" -ge "${max_reports}" ]; then
            break
        fi
    done
done <<EOF
$(find . -type f | sort)
EOF

if find . -type f | sort | while IFS= read -r path; do
    is_excluded "${path}" && continue
    is_text_file "${path}" || continue
    awk -v limit="${limit}" 'length($0) > limit { exit 1 }' "${path}" ||
        exit 1
done; then
    exit 0
fi

exit 1

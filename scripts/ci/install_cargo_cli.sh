#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "usage: $0 <crate> <binary> [version]" >&2
    exit 2
fi

crate="$1"
binary="$2"
version="${3:-}"

if command -v "${binary}" >/dev/null 2>&1; then
    "${binary}" --version
    exit 0
fi

install_args=("${crate}" --locked)
if [ -n "${version}" ]; then
    install_args+=(--version "${version}")
fi

for attempt in 1 2 3; do
    if cargo install "${install_args[@]}"; then
        "${binary}" --version
        exit 0
    fi

    if [ "${attempt}" -eq 3 ]; then
        break
    fi

    sleep "$((attempt * 10))"
done

echo "failed to install ${crate}" >&2
exit 1

# EOF

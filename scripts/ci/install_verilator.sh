#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

version="${VERILATOR_VERSION:-v5.048}"
prefix="${VERILATOR_PREFIX:-${HOME}/.local/verilator-${version}}"

add_to_path() {
    if [ -n "${GITHUB_PATH:-}" ]; then
        printf '%s/bin\n' "${prefix}" >>"${GITHUB_PATH}"
    fi
}

if [ -x "${prefix}/bin/verilator" ]; then
    add_to_path
    "${prefix}/bin/verilator" --version
    exit 0
fi

sudo apt-get update
sudo apt-get install --no-install-recommends -y \
    autoconf \
    bison \
    build-essential \
    ca-certificates \
    ccache \
    flex \
    help2man \
    perl \
    python3

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

curl -fsSL \
    "https://github.com/verilator/verilator/archive/refs/tags/${version}.tar.gz" \
    -o "${workdir}/verilator.tar.gz"
tar -xzf "${workdir}/verilator.tar.gz" -C "${workdir}"

cd "${workdir}/verilator-${version#v}"
autoconf
./configure --prefix="${prefix}"
make -j"$(nproc)"
make install

add_to_path
"${prefix}/bin/verilator" --version

# EOF

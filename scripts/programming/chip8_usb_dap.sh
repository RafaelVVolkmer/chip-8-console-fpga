#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer
# <rafael.v.volkmer@gmail.com>

set -euo pipefail

DAP_SOF=165
DAP_VERSION=1
DAP_STATUS_OK=0
DAP_CMD_ID=1
DAP_CMD_UNLOCK=2
DAP_CMD_HOLD_CORE=4
DAP_CMD_READ32=16
DAP_CMD_WRITE32=17
DAP_CMD_ROM_WRITE=33
DEFAULT_BAUD=115200
DEFAULT_TIMEOUT=1
DEFAULT_UNLOCK_KEY=0xC8DA9F0D
MAX_ROM_SIZE=$((0x0e00))
MAX_CHUNK=16

port=""
baud="${DEFAULT_BAUD}"
timeout_s="${DEFAULT_TIMEOUT}"
key="${DEFAULT_UNLOCK_KEY}"
release=1

usage() {
    cat >&2 <<'EOF'
usage: chip8_usb_dap.sh --port DEV [--baud N] COMMAND

commands:
  id
  unlock
  hold 0|1
  read32 ADDRESS
  write32 ADDRESS VALUE
  load-rom ROM [--no-release]
EOF
}

byte() {
    printf '%b' "$(printf '\\x%02x' "$(($1 & 255))")"
}

u16le() {
    value="$(($1 & 65535))"
    byte "${value}"
    byte "$((value >> 8))"
}

u32le() {
    value="$(($1 & 0xffffffff))"
    byte "${value}"
    byte "$((value >> 8))"
    byte "$((value >> 16))"
    byte "$((value >> 24))"
}

crc16_file() {
    local file="$1"
    local crc=65535
    local b
    while read -r b; do
        crc=$((crc ^ (b << 8)))
        for _ in {1..8}; do
            if ((crc & 0x8000)); then
                crc=$((((crc << 1) ^ 0x1021) & 0xffff))
            else
                crc=$(((crc << 1) & 0xffff))
            fi
        done
    done < <(od -An -v -t u1 "${file}")
    printf '%u\n' "${crc}"
}

make_packet() {
    local seq="$1"
    local cmd="$2"
    local payload="$3"
    local out="$4"
    local body="${out}.body"
    local len
    len="$(wc -c <"${payload}")"
    if ((len > 32)); then
        echo "payload too large: ${len} bytes" >&2
        exit 2
    fi
    {
        byte "${DAP_VERSION}"
        byte "${seq}"
        byte "${cmd}"
        byte "${len}"
        cat "${payload}"
    } >"${body}"

    {
        byte "${DAP_SOF}"
        cat "${body}"
        u16le "$(crc16_file "${body}")"
    } >"${out}"
}

read_exact() {
    local count="$1"
    local out="$2"
    timeout "${timeout_s}" dd "if=${port}" "of=${out}" bs=1 count="${count}" \
        status=none
    [ "$(wc -c <"${out}")" -eq "${count}" ]
}

byte_at() {
    od -An -j "$2" -N 1 -t u1 "$1" | tr -d ' '
}

send_cmd() {
    local seq="$1"
    local cmd="$2"
    local payload="$3"
    local rx_payload="$4"
    local tmp="${TMPDIR:-/tmp}/chip8-dap.$$"
    local packet="${tmp}.tx"
    local header="${tmp}.hdr"
    local crc_file="${tmp}.crc"
    local status
    local length
    local rx_seq
    local version
    local crc_rx
    local crc_calc

    make_packet "${seq}" "${cmd}" "${payload}" "${packet}"
    cat "${packet}" >"${port}"

    read_exact 5 "${header}" || {
        echo "timeout waiting for response header" >&2
        exit 1
    }

    [ "$(byte_at "${header}" 0)" -eq "${DAP_SOF}" ] || {
        echo "invalid response SOF" >&2
        exit 1
    }
    version="$(byte_at "${header}" 1)"
    rx_seq="$(byte_at "${header}" 2)"
    status="$(byte_at "${header}" 3)"
    length="$(byte_at "${header}" 4)"

    [ "${version}" -eq "${DAP_VERSION}" ] || {
        echo "invalid response version: ${version}" >&2
        exit 1
    }
    [ "${rx_seq}" -eq "$((seq & 255))" ] || {
        echo "response sequence mismatch: ${rx_seq}" >&2
        exit 1
    }

    : >"${rx_payload}"
    if [ "${length}" -gt 0 ]; then
        read_exact "${length}" "${rx_payload}" || {
            echo "timeout waiting for response payload" >&2
            exit 1
        }
    fi
    read_exact 2 "${crc_file}" || {
        echo "timeout waiting for response CRC" >&2
        exit 1
    }

    cat "${header}" >"${tmp}.crcbody"
    dd if="${tmp}.crcbody" of="${tmp}.body" bs=1 skip=1 status=none
    cat "${rx_payload}" >>"${tmp}.body"
    crc_calc="$(crc16_file "${tmp}.body")"
    crc_rx="$(od -An -v -t u1 "${crc_file}" |
        awk '{ print $1 + ($2 * 256) }')"
    [ "${crc_calc}" -eq "${crc_rx}" ] || {
        echo "response CRC mismatch" >&2
        exit 1
    }
    [ "${status}" -eq "${DAP_STATUS_OK}" ] || {
        printf 'DAP command failed: status=0x%02X\n' "${status}" >&2
        exit 1
    }
}

open_port() {
    [ -n "${port}" ] || {
        echo "--port is required" >&2
        exit 2
    }
    stty -F "${port}" "${baud}" cs8 -cstopb -parenb -ixon -ixoff \
        -crtscts raw -echo min 0 time 1
}

payload_empty() {
    : >"$1"
}

cmd_id() {
    local payload rx
    payload="$(mktemp)"
    rx="$(mktemp)"
    payload_empty "${payload}"
    send_cmd 0 "${DAP_CMD_ID}" "${payload}" "${rx}"
    LC_ALL=C tr -d '\000' <"${rx}"
    printf '\n'
}

cmd_unlock() {
    local payload rx
    payload="$(mktemp)"
    rx="$(mktemp)"
    : >"${payload}"
    u32le "${key}" >>"${payload}"
    send_cmd 1 "${DAP_CMD_UNLOCK}" "${payload}" "${rx}"
}

cmd_hold() {
    local enabled="$1"
    local payload rx
    payload="$(mktemp)"
    rx="$(mktemp)"
    : >"${payload}"
    byte "${enabled}" >>"${payload}"
    send_cmd 2 "${DAP_CMD_HOLD_CORE}" "${payload}" "${rx}"
}

cmd_read32() {
    local address="$1"
    local payload rx
    payload="$(mktemp)"
    rx="$(mktemp)"
    : >"${payload}"
    u16le "${address}" >>"${payload}"
    send_cmd 3 "${DAP_CMD_READ32}" "${payload}" "${rx}"
    od -An -v -t u1 "${rx}" |
        awk '{ printf "0x%08X\n", $1 + ($2 * 256) + ($3 * 65536) +
            ($4 * 16777216) }'
}

cmd_write32() {
    local address="$1"
    local value="$2"
    local payload rx
    payload="$(mktemp)"
    rx="$(mktemp)"
    : >"${payload}"
    u16le "${address}" >>"${payload}"
    u32le "${value}" >>"${payload}"
    send_cmd 4 "${DAP_CMD_WRITE32}" "${payload}" "${rx}"
}

chunk_crc() {
    crc16_file "$1"
}

cmd_load_rom() {
    local rom="$1"
    local size offset seq len chunk payload rx
    size="$(wc -c <"${rom}")"
    if ((size > MAX_ROM_SIZE)); then
        echo "ROM is larger than the CHIP-8 program area" >&2
        exit 1
    fi
    cmd_unlock
    cmd_hold 1
    offset=0
    seq=0
    while ((offset < size)); do
        len="${MAX_CHUNK}"
        if ((offset + len > size)); then
            len=$((size - offset))
        fi
        chunk="$(mktemp)"
        dd if="${rom}" of="${chunk}" bs=1 skip="${offset}" count="${len}" \
            status=none
        payload="$(mktemp)"
        rx="$(mktemp)"
        {
            u16le "${offset}"
            byte "${len}"
            u16le "$(chunk_crc "${chunk}")"
            cat "${chunk}"
        } >"${payload}"
        send_cmd "${seq}" "${DAP_CMD_ROM_WRITE}" "${payload}" "${rx}"
        offset=$((offset + len))
        seq=$(((seq + 1) & 255))
    done
    if ((release)); then
        cmd_hold 0
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --port)
            port="$2"
            shift 2
            ;;
        --baud)
            baud="$2"
            shift 2
            ;;
        --timeout)
            timeout_s="$2"
            shift 2
            ;;
        --key)
            key="$2"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

[ "$#" -gt 0 ] || {
    usage
    exit 2
}

command="$1"
shift
open_port

case "${command}" in
    id)
        cmd_id
        ;;
    unlock)
        cmd_unlock
        ;;
    hold)
        [ "$#" -eq 1 ] || {
            usage
            exit 2
        }
        cmd_hold "$1"
        ;;
    read32)
        [ "$#" -eq 1 ] || {
            usage
            exit 2
        }
        cmd_read32 "$1"
        ;;
    write32)
        [ "$#" -eq 2 ] || {
            usage
            exit 2
        }
        cmd_write32 "$1" "$2"
        ;;
    load-rom)
        [ "$#" -ge 1 ] || {
            usage
            exit 2
        }
        rom="$1"
        shift
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --no-release)
                    release=0
                    shift
                    ;;
                *)
                    usage
                    exit 2
                    ;;
            esac
        done
        cmd_load_rom "${rom}"
        ;;
    *)
        usage
        exit 2
        ;;
esac

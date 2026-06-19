#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

"""Generate constrained CHIP-8 fuzz ROMs for simulation and lockstep tests."""

from __future__ import annotations

import argparse
import random
from pathlib import Path


ROM_BASE = 0x200
ROM_LIMIT = 0x1000


def word(value: int) -> bytes:
    """Encode a CHIP-8 opcode as big-endian bytes."""

    return value.to_bytes(2, "big")


def generate(seed: int, opcodes: int) -> bytes:
    """Generate one constrained ROM."""

    rng = random.Random(seed)
    program: list[int] = []
    call_depth = 0
    valid_targets = [ROM_BASE + idx * 2 for idx in range(max(1, opcodes))]

    for idx in range(opcodes):
        x = rng.randrange(16)
        y = rng.randrange(16)
        kk = rng.randrange(256)
        nnn = rng.choice(valid_targets) & 0x0fff
        choice = rng.randrange(100)

        if choice < 10:
            opcode = 0x6000 | (x << 8) | kk
        elif choice < 20:
            opcode = 0x7000 | (x << 8) | kk
        elif choice < 36:
            opcode = 0x8000 | (x << 8) | (y << 4) | rng.choice(
                [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0xE]
            )
        elif choice < 44:
            opcode = 0x3000 | (x << 8) | kk
        elif choice < 52:
            opcode = 0x4000 | (x << 8) | kk
        elif choice < 60:
            opcode = 0xA000 | nnn
        elif choice < 66:
            opcode = 0xC000 | (x << 8) | kk
        elif choice < 72:
            opcode = 0xD000 | (x << 8) | (y << 4) | rng.randrange(1, 6)
        elif choice < 78:
            opcode = 0xE09E | (x << 8)
        elif choice < 84:
            opcode = 0xE0A1 | (x << 8)
        elif choice < 92:
            opcode = 0xF000 | (x << 8) | rng.choice(
                [0x07, 0x15, 0x18, 0x1E, 0x29, 0x33, 0x55, 0x65]
            )
        elif choice < 96 and call_depth < 4:
            opcode = 0x2000 | nnn
            call_depth += 1
        elif choice < 98 and call_depth > 0:
            opcode = 0x00EE
            call_depth -= 1
        elif choice < 99:
            opcode = 0x1200 | (valid_targets[min(idx, len(valid_targets) - 1)] & 0x0fff)
        else:
            opcode = 0xF000 | rng.randrange(256)
        program.append(opcode)

    program.append(0x1200 | ((ROM_BASE + max(0, opcodes - 1) * 2) & 0x0fff))
    rom = b"".join(word(opcode) for opcode in program)
    return rom[: ROM_LIMIT - ROM_BASE]


def main() -> int:
    """CLI entry point."""

    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=Path("generated/chip8/fuzz"))
    parser.add_argument("--seeds", type=int, default=16)
    parser.add_argument("--opcodes", type=int, default=128)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    for seed in range(args.seeds):
        path = args.out_dir / f"fuzz_seed_{seed:04d}.ch8"
        path.write_bytes(generate(seed, args.opcodes))
    print(f"generated {args.seeds} fuzz ROMs in {args.out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

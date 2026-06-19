// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

#include "chip8_model_ffi.h"

#include <stdint.h>
#include <stdio.h>

static int expect_u8(const char *name, uint8_t got, uint8_t expected)
{
    if (got == expected) {
        return 0;
    }

    fprintf(stderr, "%s: got %u expected %u\n", name, got, expected);
    return 1;
}

static int expect_nonzero_u32(const char *name, uint32_t got)
{
    if (got != 0u) {
        return 0;
    }

    fprintf(stderr, "%s: got zero\n", name);
    return 1;
}

int main(void)
{
    int failed = 0;
    Chip8ResultC chip8 = chip8_run_smoke(16u);
    Chip8StressResultC stress = chip8_run_architecture_stress(64u);

    failed |= expect_u8("chip8.lit_pixels", (uint8_t)chip8.lit_pixels, 22u);
    failed |= expect_u8("chip8.draw_count", (uint8_t)chip8.draw_count, 2u);
    failed |= expect_nonzero_u32("chip8.stress.cases", stress.cases);
    failed |= expect_nonzero_u32("chip8.stress.checksum", stress.checksum);
    failed |= expect_u8("chip8.stress.failures", (uint8_t)stress.failures, 0u);

    if (failed != 0) {
        return 1;
    }

    puts("c_calls_rust: PASS");
    return 0;
}

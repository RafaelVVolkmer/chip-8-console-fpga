// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

#ifndef CHIP8_MODEL_FFI_H
#define CHIP8_MODEL_FFI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Chip8ResultC {
    uint16_t pc;
    uint32_t draw_count;
    uint32_t lit_pixels;
    uint8_t halted;
} Chip8ResultC;


typedef struct Chip8StressResultC {
    uint32_t cases;
    uint32_t checksum;
    uint32_t failures;
} Chip8StressResultC;

Chip8ResultC chip8_run_smoke(uint32_t max_steps);
Chip8StressResultC chip8_run_architecture_stress(uint32_t iterations);

#ifdef __cplusplus
}
#endif

#endif

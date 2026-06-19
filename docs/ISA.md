<!--
SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
SPDX-License-Identifier: GPL-3.0-only
-->

# CHIP-8 Console FPGA ISA Reference

**Document:** `ISA.md`
**Target RTL:** `chip-8-console-fpga`
**Scope:** Instruction set implemented by the current CHIP-8 CPU RTL, including decode legality, operand fields, functional behavior, multi-cycle behavior, and illegal-opcode policy.

---

## 1. Instruction Format

All CHIP-8 instructions are 16-bit opcodes.

| Field | Bits | Meaning |
|---|---:|---|
| `opcode_class` | `[15:12]` | High opcode nibble; primary decode class |
| `x` | `[11:8]` | V-register index `Vx` |
| `y` | `[7:4]` | V-register index `Vy` |
| `n` | `[3:0]` | 4-bit immediate / sprite height |
| `kk` | `[7:0]` | 8-bit immediate |
| `nnn` | `[11:0]` | 12-bit address/immediate |

The decoder produces a packed decoded structure containing:

- raw opcode
- class/x/y/n/kk/nnn fields
- decoded operation enum
- first micro-operation type
- legality bit
- side-effect flags: writes Vx, writes VF, uses memory, uses display, uses timer, uses keypad

---

## 2. CPU Architectural State

| State | Width | Description |
|---|---:|---|
| `PC` | 12 bits | Program counter; reset target is CHIP-8 ROM base |
| `I` | 12 bits | Index register |
| `V0–VF` | 16 × 8 bits | General-purpose registers; `VF` used as flag |
| Stack | 12-bit entries | Return-address stack for `CALL`/`RET` |
| Delay timer | 8 bits | Decrements at timer tick rate |
| Sound timer | 8 bits | Decrements at timer tick rate; active when nonzero |
| Framebuffer | 64 × 32 × 1 bit | CHIP-8 monochrome display |
| Keypad | 16 bits | One bit per key |
| Memory | 4096 bytes | 12-bit address space |

---

## 3. Core FSM / Micro-Operation Model

The CPU is in-order and multi-cycle. The core state enum includes:

| State | Meaning |
|---|---|
| `FETCH` | Fetch next opcode or consume prefetch |
| `DECODE` | Latch fetched opcode |
| `EXEC` | Execute single-cycle instructions and dispatch multi-cycle work |
| `MEM_READ` | Read sprite/register memory data |
| `DRAW` | Draw sprite pixels and accumulate collision |
| `WAIT_KEY` | Stall until a key event is available |
| `TRAP` | Illegal/trap terminal state |
| `BCD0`, `BCD1`, `BCD2` | Write BCD digits |
| `STORE` | Store register burst to memory |
| `LOAD` | Load register burst from memory |
| `ALU_FLAG` | Commit `VF` after flag-producing ALU op |

First micro-operation categories:

| UOP | Description |
|---|---|
| `UOP_EXEC` | Regular execute path |
| `UOP_MEM_READ` | Memory-read sequence |
| `UOP_MEM_WRITE` | Memory-write sequence |
| `UOP_DRAW_PIXEL` | Display draw sequence |
| `UOP_WAIT_KEY` | Wait-key sequence |
| `UOP_TRAP` | Illegal/trap path |

---

## 4. Opcode Class Map

| Class nibble | Name | Implemented group |
|---:|---|---|
| `0x0` | `SYS` | `00E0`, `00EE`; other `0nnn` forms illegal |
| `0x1` | `JP` | Absolute jump |
| `0x2` | `CALL` | Subroutine call |
| `0x3` | `SEB` | Skip if `Vx == kk` |
| `0x4` | `SNEB` | Skip if `Vx != kk` |
| `0x5` | `SER` | Skip if `Vx == Vy`; only `5xy0` legal |
| `0x6` | `LDB` | Load immediate into Vx |
| `0x7` | `ADDB` | Add immediate to Vx |
| `0x8` | `ALU` | Register-register ALU subset |
| `0x9` | `SNER` | Skip if `Vx != Vy`; only `9xy0` legal |
| `0xA` | `LDI` | Load immediate into I |
| `0xB` | `JPV0` | Jump to `nnn + V0` |
| `0xC` | `RND` | Random masked immediate |
| `0xD` | `DRW` | Sprite draw |
| `0xE` | `KEY` | Key skip instructions |
| `0xF` | `MISC` | Timers, keypad wait, I arithmetic, font, BCD, register burst |

---

# 5. Instruction Reference

## 5.1 System Instructions

| Opcode | Mnemonic | Legal | Operation | Notes |
|---|---|---|---|---|
| `00E0` | `CLS` | Yes | Clear display | Clears framebuffer through display controller |
| `00EE` | `RET` | Yes | `PC = pop()` | Pops return address from stack |
| `0nnn` | `SYS nnn` | No, except above | Illegal | Current RTL only accepts `00E0` and `00EE` |

## 5.2 Flow Control

| Opcode | Mnemonic | Operation | PC behavior |
|---|---|---|---|
| `1nnn` | `JP nnn` | Jump to absolute address | `PC = nnn` |
| `2nnn` | `CALL nnn` | Push return address, jump | `push(PC+2); PC = nnn` |
| `Bnnn` | `JP V0, nnn` | Jump with V0 base | `PC = nnn + V0`, masked to 12 bits by datapath |

## 5.3 Conditional Skip

| Opcode | Mnemonic | Operation | If true | If false |
|---|---|---|---|---|
| `3xkk` | `SE Vx, kk` | Skip if equal immediate | `PC += 4` | `PC += 2` |
| `4xkk` | `SNE Vx, kk` | Skip if not equal immediate | `PC += 4` | `PC += 2` |
| `5xy0` | `SE Vx, Vy` | Skip if equal register | `PC += 4` | `PC += 2` |
| `9xy0` | `SNE Vx, Vy` | Skip if not equal register | `PC += 4` | `PC += 2` |

Only `5xy0` and `9xy0` are legal. Other low-nibble variants in classes `5` and `9` are illegal.

## 5.4 Immediate Loads and Adds

| Opcode | Mnemonic | Operation | Flags |
|---|---|---|---|
| `6xkk` | `LD Vx, kk` | `Vx = kk` | `VF` unchanged |
| `7xkk` | `ADD Vx, kk` | `Vx = Vx + kk` modulo 256 | `VF` unchanged |

## 5.5 Register ALU Instructions

| Opcode | Mnemonic | Operation | VF behavior |
|---|---|---|---|
| `8xy0` | `LD Vx, Vy` | `Vx = Vy` | unchanged |
| `8xy1` | `OR Vx, Vy` | `Vx = Vx OR Vy` | unchanged |
| `8xy2` | `AND Vx, Vy` | `Vx = Vx AND Vy` | unchanged |
| `8xy3` | `XOR Vx, Vy` | `Vx = Vx XOR Vy` | unchanged |
| `8xy4` | `ADD Vx, Vy` | `Vx = Vx + Vy` modulo 256 | `VF = carry` |
| `8xy5` | `SUB Vx, Vy` | `Vx = Vx - Vy` modulo 256 | `VF = (Vx >= Vy)` before subtraction |
| `8xy6` | `SHR Vx` | `Vx = Vx >> 1` | `VF = old Vx[0]` |
| `8xy7` | `SUBN Vx, Vy` | `Vx = Vy - Vx` modulo 256 | `VF = (Vy >= Vx)` before subtraction |
| `8xyE` | `SHL Vx` | `Vx = Vx << 1` | `VF = old Vx[7]` |

### Shift Variant Note

The RTL implements `SHR` and `SHL` using `Vx` as the shifted operand, not `Vy`. This matches the common modern CHIP-8 behavior, rather than older interpreters that used `Vy`.

### Flag Commit Note

Flag-producing ALU instructions execute as a two-step sequence:

1. Write the ALU result to `Vx`.
2. Enter `ALU_FLAG` state and write `VF`.

This makes `VF` update explicit and observable in the FSM.

## 5.6 Index Register Instructions

| Opcode | Mnemonic | Operation | Notes |
|---|---|---|---|
| `Annn` | `LD I, nnn` | `I = nnn` | 12-bit immediate |
| `Fx1E` | `ADD I, Vx` | `I = (I + Vx) & 0xFFF` | 12-bit wrapping/masked result |
| `Fx29` | `LD F, Vx` | `I = 5 * (Vx & 0xF)` | Font sprite address for low nibble |

## 5.7 Random Instruction

| Opcode | Mnemonic | Operation |
|---|---|---|
| `Cxkk` | `RND Vx, kk` | `Vx = rng_next_value & kk` |

The RNG advances when the core is enabled, in execute state, not halted, and the decoded op is random.

## 5.8 Display Instruction

| Opcode | Mnemonic | Operation |
|---|---|---|
| `Dxyn` | `DRW Vx, Vy, n` | Draw `n` sprite rows from memory at `I` to framebuffer at `(Vx, Vy)` |

Display behavior:

- Coordinates are reduced to CHIP-8 display width/height.
- Sprite bytes are read one row at a time.
- Sprite pixels are XORed into framebuffer.
- Collision is accumulated when a set pixel overlaps an already set pixel.
- `VF` is updated with collision result at the end of draw sequence.
- `n = 0` is treated as an empty sprite and returns to fetch without drawing.

## 5.9 Keypad Instructions

| Opcode | Mnemonic | Operation |
|---|---|---|
| `Ex9E` | `SKP Vx` | Skip if key indexed by low nibble of `Vx` is pressed |
| `ExA1` | `SKNP Vx` | Skip if key indexed by low nibble of `Vx` is not pressed |
| `Fx0A` | `LD Vx, K` | Wait for any key, then store first key code into `Vx` |

`Fx0A` holds `PC` in `WAIT_KEY` until a key is detected. Once a key is available, the core writes `{4'h0, key_first_pressed}` into `Vx` and resumes at `PC + 2`.

## 5.10 Timer Instructions

| Opcode | Mnemonic | Operation |
|---|---|---|
| `Fx07` | `LD Vx, DT` | `Vx = delay_timer` |
| `Fx15` | `LD DT, Vx` | `delay_timer = Vx` |
| `Fx18` | `LD ST, Vx` | `sound_timer = Vx` |

The timer module is parameterized by core clock and timer tick rate. Sound output is active when the sound timer is nonzero.

## 5.11 BCD Instruction

| Opcode | Mnemonic | Operation |
|---|---|---|
| `Fx33` | `LD B, Vx` | Store decimal BCD digits of `Vx` at memory `[I]`, `[I+1]`, `[I+2]` |

The implementation uses explicit `BCD0`, `BCD1`, and `BCD2` FSM states through a BCD writer block.

## 5.12 Register Burst Instructions

| Opcode | Mnemonic | Operation |
|---|---|---|
| `Fx55` | `LD [I], V0..Vx` | Store registers `V0` through `Vx` to memory starting at `I` |
| `Fx65` | `LD V0..Vx, [I]` | Load registers `V0` through `Vx` from memory starting at `I` |

The implementation uses a burst index and saved `x` register index. Memory address is computed as `I + burst_idx` and masked to the 12-bit CHIP-8 memory range.

---

# 6. Legal / Illegal Opcode Policy

The decoder marks unsupported encodings as illegal. The core exposes an illegal-opcode policy:

| Policy | Behavior |
|---|---|
| `ILLEGAL_AS_NOP` | Treat illegal opcode as no-op and continue |
| `ILLEGAL_TRAP` | Halt and enter `TRAP` state |
| `ILLEGAL_HALT` | Halt without trap loop |
| `TRAP_ILLEGAL=1` | Overrides policy and selects trap behavior |

Unsupported examples:

- `0nnn` other than `00E0` and `00EE`
- `5xyN` where `N != 0`
- `9xyN` where `N != 0`
- `8xy8`, `8xy9`, `8xyA`, `8xyB`, `8xyC`, `8xyD`, `8xyF`
- `Ex**` other than `Ex9E` and `ExA1`
- `Fx**` other than `07`, `0A`, `15`, `18`, `1E`, `29`, `33`, `55`, `65`

---

# 7. Instruction Side-Effect Matrix

| Instruction group | Writes Vx | Writes VF | Uses memory | Uses display | Uses timer | Uses keypad |
|---|---:|---:|---:|---:|---:|---:|
| `6xkk`, `7xkk`, `Cxkk` | Yes | No | No | No | No | No |
| `8xy0–8xy3` | Yes | No | No | No | No | No |
| `8xy4`, `8xy5`, `8xy6`, `8xy7`, `8xyE` | Yes | Yes | No | No | No | No |
| `Dxyn` | No | Yes | Yes | Yes | No | No |
| `Fx07` | Yes | No | No | No | Yes | No |
| `Fx0A` | Yes | No | No | No | No | Yes |
| `Fx15`, `Fx18` | No | No | No | No | Yes | No |
| `Fx33` | No | No | Yes | No | No | No |
| `Fx55` | No | No | Yes | No | No | No |
| `Fx65` | Yes | No | Yes | No | No | No |
| `Ex9E`, `ExA1` | No | No | No | No | No | Yes |

---

# 8. PC Update Rules

| Condition | PC behavior |
|---|---|
| Normal single instruction | `PC = PC + 2` |
| Skip condition true | `PC = PC + 4` |
| Skip condition false | `PC = PC + 2` |
| Jump/call | `PC = target` |
| Return | `PC = popped return address` |
| Wait key with no key | `PC = PC` |
| Wait key with key | `PC = PC + 2` |
| Illegal trap | `PC` held at faulting opcode |

---

# 9. Prefetch Interaction

The core has a prefetch queue for eligible sequential operations. Prefetch is flushed when:

- CPU is disabled/reset by the enable path
- RAM write occurs
- ROM loader write occurs
- Current execute instruction is not eligible for prefetch

This prevents stale prefetched opcodes after control-flow changes or memory modification.

---

# 10. Software/Validation Test ROM Checklist

A minimal ISA validation ROM should cover:

1. `00E0` clear display.
2. `6xkk` / `7xkk` register immediate behavior.
3. `3xkk`, `4xkk`, `5xy0`, `9xy0` skip paths.
4. `1nnn`, `2nnn`, `00EE` control flow.
5. `8xy0–8xyE` ALU and `VF` behavior.
6. `Annn`, `Fx1E`, `Fx29` index register behavior.
7. `Cxkk` random masking.
8. `Dxyn` draw and collision.
9. `Ex9E`, `ExA1`, `Fx0A` keypad behavior.
10. `Fx07`, `Fx15`, `Fx18` timer behavior.
11. `Fx33`, `Fx55`, `Fx65` memory write/read bursts.
12. Illegal opcode behavior under all illegal policies.

---

# 11. Source-of-Truth RTL Files

Primary files used to derive this ISA document:

- `rtl/core/chip8/pkg/chip8_isa_pkg.sv`
- `rtl/core/chip8/pkg/chip8_core_pkg.sv`
- `rtl/core/chip8/cpu/chip8_decode.sv`
- `rtl/core/chip8/cpu/chip8_control.sv`
- `rtl/core/chip8/cpu/chip8_execute.sv`
- `rtl/core/chip8/cpu/chip8_alu.sv`
- `rtl/core/chip8/cpu/chip8_core.sv`
- `rtl/core/chip8/pkg/chip8_memmap_pkg.sv`

<!-- EOF -->

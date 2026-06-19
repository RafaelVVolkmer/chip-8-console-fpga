// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

use crate::constants::{FB_SIZE, FONT, HEIGHT, ROM_BASE, WIDTH};

/// Behavioral CHIP-8 model used by the validation engine.
#[derive(Clone, Debug)]
pub struct Chip8 {
    /// Main 4 KiB CHIP-8 memory space.
    pub mem: [u8; 4096],
    /// General-purpose V registers.
    pub v: [u8; 16],
    /// Index register.
    pub i: u16,
    /// Program counter.
    pub pc: u16,
    /// Stack pointer.
    pub sp: u8,
    /// Return stack storage.
    pub stack: [u16; 16],
    /// Delay timer.
    pub delay: u8,
    /// Sound timer.
    pub sound: u8,
    /// Packed framebuffer pixels.
    pub fb: [u8; FB_SIZE],
    /// Active keypad bitmap.
    pub keys: u16,
    rng: u8,
    /// Halt flag used by the model to stop execution.
    pub halted: bool,
}

impl Default for Chip8 {
    /// Create a reset CHIP-8 machine with the built-in font ROM installed.
    fn default() -> Self {
        let mut mem = [0; 4096];
        mem[..FONT.len()].copy_from_slice(&FONT);
        Self {
            mem,
            v: [0; 16],
            i: 0,
            pc: ROM_BASE as u16,
            sp: 0,
            stack: [0; 16],
            delay: 0,
            sound: 0,
            fb: [0; FB_SIZE],
            keys: 0,
            rng: 0xa5,
            halted: false,
        }
    }
}

impl Chip8 {
    /// Load a ROM into the program area, truncating to the available space.
    pub fn load_rom(&mut self, rom: &[u8]) {
        let end = ROM_BASE + rom.len().min(4096 - ROM_BASE);
        self.mem[ROM_BASE..end].copy_from_slice(&rom[..end - ROM_BASE]);
    }

    /// Run up to `max_steps` instructions and return the number of draws.
    #[must_use]
    pub fn run(&mut self, max_steps: usize) -> u32 {
        let mut draws = 0;
        for _ in 0..max_steps {
            if self.halted {
                break;
            }
            if self.step() {
                draws += 1;
            }
        }
        draws
    }

    /// Fetch and execute one opcode, returning whether the instruction drew.
    #[must_use]
    pub fn step(&mut self) -> bool {
        let op = self.fetch_opcode();
        self.pc = self.pc.wrapping_add(2) & 0x0fff;
        self.decrement_timers();
        self.exec(op)
    }

    /// Execute one decoded opcode and return whether the instruction drew.
    #[must_use]
    pub fn exec(&mut self, op: u16) -> bool {
        let nnn = op & 0x0fff;
        let n = (op & 0x000f) as u8;
        let x = ((op >> 8) & 0x0f) as usize;
        let y = ((op >> 4) & 0x0f) as usize;
        let kk = op as u8;

        match op & 0xf000 {
            0x0000 => match op {
                0x00e0 => self.fb.fill(0),
                0x00ee => {
                    self.sp = self.sp.saturating_sub(1);
                    self.pc = self.stack[self.sp as usize];
                }
                _ => {}
            },
            0x1000 => self.pc = nnn,
            0x2000 => {
                self.stack[self.sp as usize & 0x0f] = self.pc;
                self.sp = self.sp.wrapping_add(1) & 0x0f;
                self.pc = nnn;
            }
            0x3000 if self.v[x] == kk => {
                self.pc = self.pc.wrapping_add(2);
            }
            0x4000 if self.v[x] != kk => {
                self.pc = self.pc.wrapping_add(2);
            }
            0x5000 if n == 0 && self.v[x] == self.v[y] => {
                self.pc = self.pc.wrapping_add(2);
            }
            0x6000 => self.v[x] = kk,
            0x7000 => self.v[x] = self.v[x].wrapping_add(kk),
            0x8000 => self.exec_alu(n, x, y),
            0x9000 if n == 0 && self.v[x] != self.v[y] => {
                self.pc = self.pc.wrapping_add(2);
            }
            0xa000 => self.i = nnn,
            0xb000 => self.pc = nnn.wrapping_add(u16::from(self.v[0])) & 0x0fff,
            0xc000 => {
                self.rng = self.rng.wrapping_mul(73).wrapping_add(41);
                self.v[x] = self.rng & kk;
            }
            0xd000 => return self.draw(x, y, n),
            0xe000 => self.exec_keypad(kk, x),
            0xf000 => self.exec_misc(kk, x),
            _ => {}
        }
        false
    }

    /// Apply the arithmetic and logic sub-operations for an `8xy*` opcode.
    fn exec_alu(&mut self, n: u8, x: usize, y: usize) {
        match n {
            0x0 => self.v[x] = self.v[y],
            0x1 => self.v[x] |= self.v[y],
            0x2 => self.v[x] &= self.v[y],
            0x3 => self.v[x] ^= self.v[y],
            0x4 => {
                let (value, carry) = self.v[x].overflowing_add(self.v[y]);
                self.v[x] = value;
                self.v[0xf] = carry as u8;
            }
            0x5 => {
                let (value, borrow) = self.v[x].overflowing_sub(self.v[y]);
                self.v[x] = value;
                self.v[0xf] = (!borrow) as u8;
            }
            0x6 => {
                self.v[0xf] = self.v[x] & 1;
                self.v[x] >>= 1;
            }
            0x7 => {
                let (value, borrow) = self.v[y].overflowing_sub(self.v[x]);
                self.v[x] = value;
                self.v[0xf] = (!borrow) as u8;
            }
            0xe => {
                self.v[0xf] = (self.v[x] >> 7) & 1;
                self.v[x] <<= 1;
            }
            _ => {}
        }
    }

    /// Apply keypad-related `Ex9E` and `ExA1` skip semantics.
    fn exec_keypad(&mut self, kk: u8, x: usize) {
        match kk {
            0x9e if (self.keys & (1u16 << (self.v[x] & 0x0f))) != 0 => {
                self.pc = self.pc.wrapping_add(2);
            }
            0xa1 if (self.keys & (1u16 << (self.v[x] & 0x0f))) == 0 => {
                self.pc = self.pc.wrapping_add(2);
            }
            _ => {}
        }
    }

    /// Apply timer, memory and BCD helper opcodes from the `Fx**` family.
    fn exec_misc(&mut self, kk: u8, x: usize) {
        match kk {
            0x07 => self.v[x] = self.delay,
            0x0a => {
                if self.keys == 0 {
                    self.pc = self.pc.wrapping_sub(2);
                } else {
                    self.v[x] = self.keys.trailing_zeros() as u8;
                }
            }
            0x15 => self.delay = self.v[x],
            0x18 => self.sound = self.v[x],
            0x1e => {
                self.i = self.i.wrapping_add(u16::from(self.v[x]));
                self.i &= 0x0fff;
            }
            0x29 => self.i = u16::from(self.v[x] & 0x0f) * 5,
            0x33 => {
                let value = self.v[x];
                let base = Self::mem_index(self.i as usize);
                self.mem[base] = value / 100;
                self.mem[Self::mem_index(base + 1)] = (value / 10) % 10;
                self.mem[Self::mem_index(base + 2)] = value % 10;
            }
            0x55 => {
                for idx in 0..=x {
                    self.mem[Self::mem_index(self.i as usize + idx)] =
                        self.v[idx];
                }
            }
            0x65 => {
                for idx in 0..=x {
                    self.v[idx] =
                        self.mem[Self::mem_index(self.i as usize + idx)];
                }
            }
            _ => {}
        }
    }

    /// Draw a sprite into the framebuffer and report whether a collision occurred.
    #[must_use]
    fn draw(&mut self, x: usize, y: usize, n: u8) -> bool {
        let base_x = self.v[x] as usize % WIDTH;
        let base_y = self.v[y] as usize % HEIGHT;
        self.v[0xf] = 0;
        for row in 0..usize::from(n) {
            let sprite = self.mem[Self::mem_index(self.i as usize + row)];
            for bit in 0..8 {
                if (sprite & (0x80 >> bit)) == 0 {
                    continue;
                }
                let px = (base_x + bit) % WIDTH;
                let py = (base_y + row) % HEIGHT;
                let index = py * WIDTH + px;
                if self.fb[index] != 0 {
                    self.v[0xf] = 1;
                }
                self.fb[index] ^= 1;
            }
        }
        true
    }

    /// Count the number of lit pixels in the framebuffer.
    #[must_use]
    pub fn lit_pixels(&self) -> u32 {
        self.fb.iter().map(|&pixel| u32::from(pixel != 0)).sum()
    }

    /// Fetch the current 16-bit opcode without mutating architectural state.
    #[must_use]
    fn fetch_opcode(&self) -> u16 {
        let pc = Self::mem_index(self.pc as usize);
        let next = Self::mem_index(pc + 1);
        (u16::from(self.mem[pc]) << 8) | u16::from(self.mem[next])
    }

    /// Decrement the delay and sound timers with saturating semantics.
    fn decrement_timers(&mut self) {
        if self.delay != 0 {
            self.delay = self.delay.saturating_sub(1);
        }
        if self.sound != 0 {
            self.sound = self.sound.saturating_sub(1);
        }
    }

    /// Mask a CHIP-8 address into the 4 KiB architectural memory space.
    #[must_use]
    fn mem_index(addr: usize) -> usize {
        addr & 0x0fff
    }
}

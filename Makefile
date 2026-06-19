# SPDX-License-Identifier: GPL-3.0-only
# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>

# CHIP-8 SoC validation, simulation, synthesis, formal verification,
# board programming, and cleanup Makefile.

# ==============================================================================
# SHELL CONFIGURATION
# ==============================================================================

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# ==============================================================================
# DEFAULT PROJECT CONFIGURATION
# ==============================================================================

TOP ?= tb_chip8_top
RTL_TOP ?= chip8_top
FILES ?= files.f

BOARD ?=
PART ?=
FAMILY ?=

REPORTS ?= reports
CC ?= cc

# ==============================================================================
# PROGRAMMING / ROM CONFIGURATION
# ==============================================================================

PORT ?= /dev/ttyACM1
BAUD ?= 115200
BITSTREAM ?= build/tang_nano_9k/impl/pnr/project.fs

CHIP8_ROM ?= validation/programs/chip8/smoke.ch8
CHIP8_ROM_MEM ?= validation/programs/chip8/smoke.mem
CHIP8_ROM_DIR ?= validation/programs/chip8/roms
CHIP8_ROM_MEM_DIR ?= generated/chip8/roms
CHIP8_ROM_STEPS ?= 2500

# ==============================================================================
# BOARD DATABASE
# ==============================================================================

BOARD_TOP_cyclone_v := cyclone_v_top
BOARD_TOP_artix_a7 := artix_a7_top
BOARD_TOP_tang_nano_9k := tang_nano_9k_top

BOARD_PART_cyclone_v := 5CSEBA6U23I7
BOARD_PART_artix_a7 := xc7a35ticsg324-1L
BOARD_PART_tang_nano_9k := GW1NR-LV9QN88PC6/I5

BOARD_FAMILY_cyclone_v := Cyclone V
BOARD_FAMILY_tang_nano_9k := Gowin GW1NR-9

CV_BUILD := build/cyclone_v_top_quartus
CV_SOF := cyclone_v_top.sof

BOARD_BUILD_cyclone_v := $(CV_BUILD)
BOARD_BITSTREAM_cyclone_v := $(CV_BUILD)/output_files/$(CV_SOF)
BOARD_BITSTREAM_artix_a7 := build/artix_a7_top/artix_a7_top.bit
BOARD_BITSTREAM_tang_nano_9k := build/tang_nano_9k/impl/pnr/project.fs

BOARD_LOADER_cyclone_v := de10nano
BOARD_LOADER_artix_a7 := arty_a7_35t
BOARD_LOADER_tang_nano_9k := tangnano9k

# ==============================================================================
# SELECTED BOARD / TOOLCHAIN CONFIGURATION
# ==============================================================================

SELECTED_TOP := $(if $(BOARD),$(BOARD_TOP_$(BOARD)),$(RTL_TOP))
SELECTED_PART := $(if $(PART),$(PART),$(BOARD_PART_$(BOARD)))
SELECTED_FAMILY := $(if $(FAMILY),$(FAMILY),$(BOARD_FAMILY_$(BOARD)))
SELECTED_FILES := $(FILES)
SELECTED_BITSTREAM := $(if $(BOARD),$(BOARD_BITSTREAM_$(BOARD)),$(BITSTREAM))
SELECTED_LOADER := $(BOARD_LOADER_$(BOARD))

# ==============================================================================
# FORMAL VERIFICATION TARGETS
# ==============================================================================

FORMAL_TARGETS := \
	validation/formal/protocol/chip8_protocol_blocks.sby \
	validation/formal/core/chip8_blocks.sby \
	validation/formal/core/chip8_components.sby \
	validation/formal/core/chip8_top.sby \
	validation/formal/soc/axi/chip8_boot_pipeline.sby \
	validation/formal/soc/axi/chip8_soc_axi.sby \
	validation/formal/soc/keypad/chip8_keypad.sby \
	validation/formal/soc/video/chip8_video.sby \
	validation/formal/boards/tang_nano_9k/tang_nano_9k.sby

FORMAL_COVER_TARGETS := \
	validation/formal/coverage/chip8_cover.sby

# ==============================================================================
# CLEANUP CONFIGURATION
# ==============================================================================

CLEAN_DIRS := \
	obj \
	obj_dir \
	obj_dir_* \
	build \
	generated \
	$(REPORTS) \
	logs \
	outputs \
	coverage \
	verilator_coverage \
	sim_build \
	.gowin \
	gowin_dtemp \
	validation/formal/core/chip8_blocks \
	validation/formal/soc/axi/chip8_boot_pipeline \
	validation/formal/core/chip8_components \
	validation/formal/core/chip8_top \
	validation/formal/coverage/chip8_cover \
	validation/formal/protocol/chip8_protocol_blocks \
	validation/formal/soc/axi/chip8_soc_axi \
	validation/formal/soc/keypad/chip8_keypad \
	validation/formal/soc/video/chip8_video \
	validation/formal/boards/tang_nano_9k/tang_nano_9k \
	validation/rust/target \
	.Xil \
	xsim.dir \
	incremental_db \
	output_files \
	db

CLEAN_EXPLICIT_FILES := \
	$(CHIP8_ROM_MEM)

CLEAN_FIND_DIRS := \
	__pycache__ \
	.pytest_cache \
	.mypy_cache \
	.ruff_cache \
	sby-* \
	engine_*

CLEAN_FILES := \
	*:Zone.Identifier \
	*.vcd \
	*.fst \
	*.ghw \
	*.lxt \
	*.lxt2 \
	*.vpd \
	*.d \
	*.o \
	*.a \
	*.so \
	*.gcda \
	*.gcno \
	*.gcov \
	*.jou \
	*.log \
	*.rpt \
	*.str \
	*.wdb \
	*.ucdb \
	*.vstf \
	*.xpr \
	*.qpf \
	*.qsf \
	*.sof \
	*.pof \
	*.fs \
	*.bit \
	*.bin \
	*.svf \
	*.xsvf \
	*.rpd \
	*.rbf \
	*.asc \
	*.blif \
	*.edif \
	*.edf \
	*.edn \
	*.ngc \
	*.ngd \
	*.vqm \
	*.vo \
	*.sdf \
	*.smt2 \
	*.btor \
	*.yw \
	*.wit \
	*.aiw \
	*.cex \
	coverage.dat \
	results.xml \
	cocotb_results.xml \
	transcript \
	vsim.wlf

# ==============================================================================
# PHONY TARGETS
# ==============================================================================

.PHONY: \
	all check quick-check regression full-regression toolcheck reuse-check \
	check-conf conf \
	axi-lint axi-sim axi-check tang-nano-9k-check \
	tang-nano-9k-synth tang-nano-9k-program-sram \
	tang-nano-9k-program-flash boot-pipeline-sim \
	software-check rust-fmt rust-check rust-clippy rust-test rust-doc \
	rust-release rust-nightly-aggressive rust-validation ffi-test \
	lint sim chip8-rom chip8-components-sim chip8-blocks-sim \
	chip8-sim chip8-roms-sim yosys synth-check synthesis \
	synthesis-yosys formal formal-syntax formal-cover coverage \
	board-synth board-program xilinx-synth intel-synth \
	vivado-synth quartus-synth usb-dap-id usb-dap-load-rom clean

# ==============================================================================
# TOP-LEVEL FLOWS
# ==============================================================================

all: check

check: reuse-check full-regression synthesis coverage check-conf

quick-check: \
	toolcheck \
	software-check \
	lint \
	chip8-components-sim \
	chip8-blocks-sim \
	chip8-sim \
	axi-sim \
	yosys \
	axi-check \
	tang-nano-9k-check \
	formal-syntax

regression: quick-check chip8-roms-sim formal

full-regression: regression formal-cover

# ==============================================================================
# TOOLCHAIN CHECKS
# ==============================================================================

toolcheck:
	@command -v cargo >/dev/null || exit 127
	@command -v $(CC) >/dev/null || exit 127
	@command -v verilator >/dev/null || exit 127
	@command -v yosys >/dev/null || exit 127
	@command -v sby >/dev/null || exit 127
	@command -v reuse >/dev/null || exit 127

reuse-check:
	reuse lint

check-conf conf:
	bash scripts/quality/check_conf.sh

# ==============================================================================
# SOFTWARE VALIDATION
# ==============================================================================

software-check: rust-fmt rust-check rust-clippy rust-test rust-doc rust-release rust-validation ffi-test

rust-fmt:
	cd validation/rust && cargo fmt --all --check

rust-check:
	cd validation/rust && RUSTFLAGS="-D warnings" cargo check-all

rust-clippy:
	cd validation/rust && RUSTFLAGS="-D warnings" cargo clippy-all

rust-test:
	cd validation/rust && RUSTFLAGS="-D warnings" cargo test-release

rust-doc:
	cd validation/rust && RUSTDOCFLAGS="-D warnings" cargo doc-strict

rust-release:
	cd validation/rust && RUSTFLAGS="-D warnings" cargo build-release

rust-nightly-aggressive:
	cd validation/rust && cargo +nightly rustc --release \
		-p chip8-model \
		--lib \
		--config .cargo/nightly-aggressive.toml \
		--crate-type staticlib

rust-validation:
	cd validation/rust && cargo run -q -p chip8-model --bin chip8-model -- 1024

ffi-test:
	cd validation/rust && cargo build -q -p chip8-model --release
	mkdir -p build
	$(CC) validation/ffi/tests/c_calls_rust.c \
		-Ivalidation/ffi/include \
		-Lvalidation/rust/target/release \
		-lchip8_model \
		-lpthread \
		-ldl \
		-lm \
		-o build/c_calls_rust
	LD_LIBRARY_PATH=validation/rust/target/release ./build/c_calls_rust

# ==============================================================================
# RTL LINT / SIMULATION
# ==============================================================================

lint:
	bash scripts/verification/verilator_lint.sh
	bash scripts/verification/verilator_axi_lint.sh
	@if command -v svlint >/dev/null 2>&1; then \
		svlint -f $(FILES); \
	else \
		echo "svlint not found; skipped"; \
	fi

sim:
	TOP=$(TOP) bash scripts/simulation/verilator_sim.sh

chip8-rom:
	cd validation/rust && cargo run -q \
		-p chip8-model \
		--bin gen-chip8-rom \
		-- ../../$(CHIP8_ROM) ../../$(CHIP8_ROM_MEM)

chip8-components-sim:
	TOP=tb_chip8_components bash scripts/simulation/verilator_sim.sh

chip8-blocks-sim:
	TOP=tb_chip8_blocks_exhaustive \
	MDIR=obj/tb_chip8_blocks_exhaustive \
	bash scripts/simulation/verilator_sim.sh

chip8-sim: chip8-rom
	TOP=tb_chip8_top \
	SIM_ARGS="+CHIP8_ROM_MEM=$(CHIP8_ROM_MEM)" \
	bash scripts/simulation/verilator_sim.sh

chip8-roms-sim:
	CHIP8_ROM_DIR=$(CHIP8_ROM_DIR) \
	CHIP8_ROM_MEM_DIR=$(CHIP8_ROM_MEM_DIR) \
	CHIP8_ROM_STEPS=$(CHIP8_ROM_STEPS) \
	bash scripts/simulation/chip8_run_roms.sh

# ==============================================================================
# AXI / SOC VALIDATION
# ==============================================================================

axi-lint:
	bash scripts/verification/verilator_axi_lint.sh

axi-sim:
	TOP=tb_chip8_axi_lite \
	MDIR=obj/tb_chip8_axi_lite \
	bash scripts/simulation/verilator_sim.sh
	TOP=tb_chip8_keypad_remote_core \
	MDIR=obj/tb_chip8_keypad_remote_core \
	bash scripts/simulation/verilator_sim.sh
	TOP=tb_chip8_video_remote_core \
	MDIR=obj/tb_chip8_video_remote_core \
	bash scripts/simulation/verilator_sim.sh
	TOP=tb_tang_nano_9k_top \
	MDIR=obj/tb_tang_nano_9k_top \
	bash scripts/simulation/verilator_sim.sh
	TOP=tb_chip8_boot_pipeline \
	MDIR=obj/tb_chip8_boot_pipeline \
	bash scripts/simulation/verilator_sim.sh
	TOP=tb_chip8_dap_protocol \
	MDIR=obj/tb_chip8_dap_protocol \
	bash scripts/simulation/verilator_sim.sh

boot-pipeline-sim:
	TOP=tb_chip8_boot_pipeline \
	MDIR=obj/tb_chip8_boot_pipeline \
	bash scripts/simulation/verilator_sim.sh

axi-check:
	mkdir -p $(REPORTS)
	yosys -s scripts/verification/yosys_soc_axi_check.ys \
		| tee $(REPORTS)/yosys_soc_axi_check.log

tang-nano-9k-check:
	mkdir -p $(REPORTS)
	yosys -s scripts/verification/yosys_tang_nano_9k_check.ys \
		| tee $(REPORTS)/yosys_tang_nano_9k_check.log

# ==============================================================================
# TANG NANO 9K FLOW
# ==============================================================================

tang-nano-9k-synth:
	gw_sh scripts/synthesis/tang_nano_9k.tcl

tang-nano-9k-program-sram:
	openFPGALoader -b tangnano9k $(BITSTREAM)

tang-nano-9k-program-flash:
	openFPGALoader -b tangnano9k -f $(BITSTREAM)

# ==============================================================================
# YOSYS / GENERIC SYNTHESIS
# ==============================================================================

yosys synth-check:
	mkdir -p $(REPORTS)
	yosys -s scripts/verification/yosys_check.ys \
		| tee $(REPORTS)/yosys_check.log

synthesis synthesis-yosys:
	mkdir -p $(REPORTS)
	yosys -s scripts/synthesis/yosys_synth.ys \
		| tee $(REPORTS)/yosys_synth.log
	yosys -s scripts/verification/yosys_soc_axi_check.ys \
		| tee $(REPORTS)/yosys_soc_axi_synth_check.log
	yosys -s scripts/verification/yosys_tang_nano_9k_check.ys \
		| tee $(REPORTS)/yosys_tang_nano_9k_synth_check.log

# ==============================================================================
# FORMAL VERIFICATION
# ==============================================================================

formal:
	@set -e; \
	for target in $(FORMAL_TARGETS); do \
		echo "==> sby -f $$target"; \
		sby -f $$target; \
	done

formal-cover:
	@set -e; \
	for target in $(FORMAL_COVER_TARGETS); do \
		echo "==> sby -f $$target"; \
		sby -f $$target; \
	done

formal-syntax:
	yosys -q -s validation/formal/core/chip8_top_syntax.ys

# ==============================================================================
# COVERAGE
# ==============================================================================

coverage:
	bash scripts/simulation/verilator_coverage.sh

# ==============================================================================
# VENDOR SYNTHESIS FLOWS
# ==============================================================================

vivado-synth:
	test -n "$(SELECTED_TOP)"
	test -n "$(SELECTED_PART)"
	RTL_TOP=$(SELECTED_TOP) \
	PART=$(SELECTED_PART) \
	FILES=$(SELECTED_FILES) \
	vivado -mode batch -source scripts/synthesis/vivado_synth.tcl

quartus-synth:
	test -n "$(SELECTED_TOP)"
	test -n "$(SELECTED_PART)"
	RTL_TOP=$(SELECTED_TOP) \
	PART=$(SELECTED_PART) \
	FAMILY="$(SELECTED_FAMILY)" \
	FILES=$(SELECTED_FILES) \
	quartus_sh -t scripts/synthesis/quartus_synth.tcl

board-synth:
	@if [ "$(BOARD)" = "tang_nano_9k" ]; then \
		$(MAKE) tang-nano-9k-synth; \
	elif [ "$(BOARD)" = "artix_a7" ]; then \
		$(MAKE) vivado-synth BOARD=$(BOARD) PART="$(PART)"; \
	elif [ "$(BOARD)" = "cyclone_v" ]; then \
		$(MAKE) quartus-synth BOARD=$(BOARD) PART="$(PART)"; \
	else \
		echo "Unsupported BOARD=$(BOARD). Use tang_nano_9k, cyclone_v, or artix_a7." >&2; \
		exit 2; \
	fi

xilinx-synth:
	$(MAKE) vivado-synth BOARD=artix_a7 PART="$(PART)"

intel-synth:
	$(MAKE) quartus-synth BOARD=cyclone_v PART="$(PART)"

# ==============================================================================
# BOARD PROGRAMMING
# ==============================================================================

board-program:
	test -n "$(BOARD)"
	test -n "$(SELECTED_LOADER)"
	openFPGALoader -b $(SELECTED_LOADER) $(SELECTED_BITSTREAM)

usb-dap-id:
	bash scripts/programming/chip8_usb_dap.sh \
		--port $(PORT) \
		--baud $(BAUD) \
		id

usb-dap-load-rom:
	bash scripts/programming/chip8_usb_dap.sh \
		--port $(PORT) \
		--baud $(BAUD) \
		load-rom $(CHIP8_ROM)

# ==============================================================================
# CLEANUP
# ==============================================================================

clean:
	rm -rf $(CLEAN_DIRS)
	rm -f $(CLEAN_EXPLICIT_FILES)
	find . -maxdepth 3 -type f \( \
		$(foreach f,$(CLEAN_FILES),-name '$(f)' -o) \
		-false \
		\) -delete
	find . -maxdepth 4 -type d \( \
		$(foreach d,$(CLEAN_FIND_DIRS),-name '$(d)' -o) \
		-false \
		\) -prune -exec rm -rf {} +


# EOF

#*******************************************************************************
# Creator:        Hai Cao Xuan (caoxuanhaipr@gmail.com)
# Description:    makefile
#*******************************************************************************
# Copyright (c) 2022 Hai Cao Xuan
#*******************************************************************************

FILELIST_ARGS := $(shell sed -n '/^[+-]/p' filelist)
FILES := $(shell sed -n '/^[^+-]/p' filelist)

VERILATOR = verilator
VERILATOR_COV = verilator_coverage
TEST ?= all_suit
CORE_MODE ?= 0
SIM_CXX ?= g++-10
OBJ_DIR = obj_dir_mode$(CORE_MODE)$(if $(filter riscv_card,$(TEST)),_riscv_card)
TESTBENCH = $(if $(filter riscv_card,$(TEST)),./bin/tb_riscv_card.cpp,./bin/tb_top.cpp)
STATIC_BRANCH_TB = ../01_bench/static_branch/tbench.sv
STATIC_BRANCH_FLAGS = --binary --timing --assert -sv -Wall -Wno-EOFNEWLINE -Wno-PINCONNECTEMPTY --top-module tbench -CFLAGS -std=gnu++20

### LINT FLAGS
LINT_FLAGS = -Wall --lint-only -sv

### VERILATE FLAGS
# Generate C++ in executable form
VERILATOR_FLAGS += -sv -cc
# Optimize
VERILATOR_FLAGS += -x-initial unique
VERILATOR_FLAGS += -x-assign unique
VERILATOR_FLAGS += -O3 -CFLAGS -DCOVERAGE
# Warn abount lint issues; may not want this on less solid designs
VERILATOR_FLAGS += -Wall
VERILATOR_FLAGS += -Wno-EOFNEWLINE
VERILATOR_FLAGS += -Wno-PINCONNECTEMPTY
# Enable assertion
VERILATOR_FLAGS += --assert
# Make waveforms
VERILATOR_FLAGS += --trace-fst
VERILATOR_FLAGS += -GCORE_MODE=$(CORE_MODE)
VERILATOR_FLAGS += -Mdir $(OBJ_DIR)

# Input files for Verilator
VERILATOR_INPUT = $(FILELIST_ARGS) $(FILES) ./bin/top.sv --top-module top

.PHONY: all
all:
	make test

.PHONY: help
help:
	@echo -e "make [option]"
	@echo -e "\tbuild   verilate and build modules"
	@echo -e "\ttest    run $(TEST) and dump its FST waveform"
	@echo -e "\t        CORE_MODE=0 single-cycle, 1 stall-only, 2 hazard, 3 TOP_SYNTH"
	@echo -e "\t        CORE_MODE=4 not-always-jump, 5 always-jump"
	@echo -e "\twave    run $(TEST) and open its waveform"
	@echo -e "\ttest-static-branch  check both static policies and branch recovery on all_suit"
	@echo -e "\ttest-control-redirect  check EX redirects, ID stalls, and older memory waits"
	@echo -e "\t        TEST=riscv_card runs the reference-card instruction tests"
	@echo -e "\tclean   clean the working folder"
	@echo -e "\thelp    print this help"

.PHONY: build
build: $(OBJ_DIR)/Vtop
$(OBJ_DIR)/Vtop: $(FILES) $(TESTBENCH) ./bin/top.sv ./filelist ./makefile
	@$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_INPUT) --exe $(TESTBENCH) > build.log
	@$(MAKE) -C $(OBJ_DIR) -f Vtop.mk -j2

.PHONY: test
test: $(OBJ_DIR)/Vtop
	@./$(OBJ_DIR)/Vtop $(TEST) $(if $(filter riscv_card,$(TEST)),+MODE=$(CORE_MODE),+trace)

ifeq ($(TEST),riscv_card)
test: riscv-card-roms
endif

.PHONY: riscv-card-roms
riscv-card-roms:
	@python3 tests/riscv_card/generate.py

.PHONY: test-static-branch
test-static-branch: obj_dir_static_not_taken/Vtbench obj_dir_static_taken/Vtbench
	@./obj_dir_static_not_taken/Vtbench
	@./obj_dir_static_taken/Vtbench

obj_dir_static_not_taken/Vtbench: $(FILES) $(STATIC_BRANCH_TB) ./filelist
	@MAKEFLAGS='CXX=$(SIM_CXX)' $(VERILATOR) $(STATIC_BRANCH_FLAGS) $(filter-out +define+DV,$(FILELIST_ARGS)) $(FILES) $(STATIC_BRANCH_TB) -Mdir obj_dir_static_not_taken > build_static_not_taken.log 2>&1

obj_dir_static_taken/Vtbench: $(FILES) $(STATIC_BRANCH_TB) ./filelist
	@MAKEFLAGS='CXX=$(SIM_CXX)' $(VERILATOR) $(STATIC_BRANCH_FLAGS) $(filter-out +define+DV,$(FILELIST_ARGS)) $(FILES) $(STATIC_BRANCH_TB) +define+TEST_ALWAYS_JUMP -Mdir obj_dir_static_taken > build_static_taken.log 2>&1

.PHONY: wave
.PHONY: test-control-redirect
test-control-redirect: obj_dir_control_redirect/Vtbench
	@./obj_dir_control_redirect/Vtbench

obj_dir_control_redirect/Vtbench: ../01_bench/control_redirect/tbench.sv ../00_src/hazard_ctrl.sv ../00_src/rv32i_pkg.sv ./makefile
	@MAKEFLAGS='CXX=$(SIM_CXX)' $(VERILATOR) $(STATIC_BRANCH_FLAGS) ../00_src/rv32i_pkg.sv ../00_src/hazard_ctrl.sv ../01_bench/control_redirect/tbench.sv -Mdir obj_dir_control_redirect > build_control_redirect.log 2>&1

wave: test
	@gtkwave wave_$(TEST).fst wave.gtkw

.PHONY: clean
clean:
	@rm -rf obj_dir obj_dir_mode*
	@rm -f wave*.fst
	@rm -f *.log

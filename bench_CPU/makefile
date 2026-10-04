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
OBJ_DIR = obj_dir_mode$(CORE_MODE)

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
	@echo -e "\twave    run $(TEST) and open its waveform"
	@echo -e "\tclean   clean the working folder"
	@echo -e "\thelp    print this help"

.PHONY: build
build: $(OBJ_DIR)/Vtop
$(OBJ_DIR)/Vtop: $(FILES) ./bin/tb_top.cpp ./bin/top.sv ./filelist
	@$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_INPUT) --exe ./bin/tb_top.cpp > build.log
	@$(MAKE) -C $(OBJ_DIR) -f Vtop.mk -j2

.PHONY: test
test: $(OBJ_DIR)/Vtop
	@./$(OBJ_DIR)/Vtop $(TEST) +trace

.PHONY: wave
wave: test
	@gtkwave wave_$(TEST).fst wave.gtkw

.PHONY: clean
clean:
	@rm -rf obj_dir obj_dir_mode*
	@rm -f wave*.fst
	@rm -f *.log

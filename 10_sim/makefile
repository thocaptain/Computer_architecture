# Author: Hai Cao -- cxhai.sdh221@hcmut.edu.vn
# Copyright 2024

TOP=tbench
SEED=1
SIM_CXX ?= g++-10

## Do NOT change the content below unless you know what you're doing
FLAGS =  --binary -Wall --trace --sv --timing --trace-structs --trace-max-array 512 --trace-max-width 64
FLAGS += -O3 --compiler gcc -CFLAGS -std=gnu++20
FLAGS += -Wno-EOFNEWLINE
FLAGS += -Wno-PINCONNECTEMPTY
FLAGS += -x-initial unique
FLAGS += -x-assign unique
FLAGS += --assert
FLAGS += --build -j 0
LFLAGS = --lint-only --sv --timing
RFLAGS =  +verilator+seed+$(SEED)

TARGET = -f ./flist

.PHONY: lint
lint:
	@echo "-> LINT"
	verilator $(LFLAGS) $(TARGET)

.PHONY: sim
sim:
	@echo "-> SIMULATION"
	MAKEFLAGS='CXX=$(SIM_CXX)' verilator $(FLAGS) $(TARGET)

.PHONY: run
run:
	@echo "-> RUN"
	./obj_dir/V$(TOP) $(RFLAGS)

.PHONY: wave
wave:
	gtkwave wave.vcd wave.gtkw 2>/dev/null

.PHONY: clean
clean:
	@echo "-> CLEAN"
	@rm -rf ./obj_dir *.vcd

# Milestone 1 simulation (Verilator >= 5, GNU make, g++). Run from Linux/WSL.
#
#   make run TB=adder         build + run one testbench
#   make all                  build + run every testbench
#   make lint                 lint all RTL
#   make clean
#
# TB: adder | comparator | shifter | alu | regfile | dmem_async | dmem_sync

TB      ?= adder
TB_LIST  = adder comparator shifter alu regfile dmem_async dmem_sync

SRC_DIR  = ../00_src
BENCH    = ../01_bench

SRC = $(SRC_DIR)/alu_pkg.sv \
      $(SRC_DIR)/adder.sv \
      $(SRC_DIR)/comparator.sv \
      $(SRC_DIR)/shifter.sv \
      $(SRC_DIR)/alu.sv \
      $(SRC_DIR)/regfile.sv \
      $(SRC_DIR)/dmem_async.sv \
      $(SRC_DIR)/dmem_sync.sv

VFLAGS = --sv --timing --assert --trace -Wall -Wno-fatal -Wno-DECLFILENAME

.PHONY: build run all lint clean

build:
	verilator --binary $(VFLAGS) --top-module tbench $(SRC) $(BENCH)/$(TB)/tbench.sv \
	  -Mdir obj_dir_$(TB) --quiet

run: build
	./obj_dir_$(TB)/Vtbench

all:
	@for tb in $(TB_LIST); do $(MAKE) --no-print-directory run TB=$$tb || exit 1; done

lint:
	@for m in adder comparator shifter alu regfile dmem_async dmem_sync; do \
	  verilator --lint-only $(VFLAGS) --top-module $$m $(SRC); \
	done

clean:
	rm -rf obj_dir_* *.vcd

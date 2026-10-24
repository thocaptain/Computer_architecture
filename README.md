# RV32I CPU Workspace

A workspace for RV32I CPU implementations, testbenches, assembly programs, simulation, and FPGA projects.

## Workspace Structure

| Directory       | Contents                                                                                                       |
| --------------- | -------------------------------------------------------------------------------------------------------------- |
| `00_src/`       | RTL sources: packages, ALU, LSU, register file, memory, single-cycle core, pipeline cores, and board wrappers. |
| `01_bench/`     | SystemVerilog testbenches, drivers, and scoreboards.                                                           |
| `02_test/asm/`  | Assembly programs used to verify and test the CPU.                                                             |
| `02_test/dump/` | Corresponding ROM images in hexadecimal format; for example, `all_suit.mem`.                                   |
| `03_script/`    | Scripts for generating and converting ROM images and other supporting data.                                    |
| `10_sim/`       | General-purpose Verilator simulation; the testbench is selected through `10_sim/flist`.                        |
| `20_syn/`       | FPGA synthesis, timing, and pin-assignment configurations.                                                     |
| `30_demo/`      | Hardware demonstration projects.                                                                               |
| `99_doc/`       | Design documentation and diagrams.                                                                             |
| `bench_CPU/`    | Regression runner for CPU ROM tests; the core is selected using `CORE_MODE`.                                   |

## Regression in `bench_CPU`

Run the regression from WSL inside the `bench_CPU` directory.

The project uses Verilator 5.x from OSS CAD Suite. Verilator 4.028 on the current system does not support the project's `--binary` option.

```sh
cd /home/lqhau/RISC-V-RV32i-master/bench_CPU

make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=0 TEST=all_suit
```

### `CORE_MODE`

| Mode | Core                    | Description                                                                    |
| ---- | ----------------------- | ------------------------------------------------------------------------------ |
| `0`  | `TOP_SINGLE_CYCLE`      | Single-cycle CPU; default mode.                                                |
| `1`  | `rv32i_pipeline_stall`  | Pipeline CPU with stalls for RAW hazards; no forwarding or branch prediction.  |
| `2`  | `rv32i_pipeline_hazard` | Pipeline CPU with forwarding and load-use hazard stalls; no branch prediction. |
| `3`  | `TOP_SYNTH`             | Full pipeline implementation with tournament branch prediction.                |
| `4`  | `rv32i_not_always_jump` | Pipeline with forwarding and static not-taken branch prediction.               |
| `5`  | `rv32i_always_jump`     | Pipeline with forwarding and static taken prediction on BTB hits.              |

The two static-prediction tops expose the same CPU, MMIO, and SRAM ports as
`TOP_SINGLE_CYCLE`, with `INST_MEM_ADDR_W`, `MEM_TYPE`, and `CACHE` parameters.
Both enable forwarding and load-use stalls; cache is enabled by default.

`rv32i_not_always_jump` predicts `PC + 4` for every conditional branch. It uses the
same core configuration as `rv32i_pipeline_hazard`, with an explicit top name
for branch-prediction comparisons.

`rv32i_always_jump` uses the existing `PRED_NONE` strategy: every BTB hit predicts
taken to the saved target, without consulting the local/global direction
predictors. A cold BTB miss follows `PC + 4`; decode learns the branch target for
later fetches. An incorrect prediction is recovered in EX. These policies apply
to conditional branches; JAL/JALR retain their existing jump behavior.

### Running Different Pipeline Stages

For example:

```sh
make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=1 TEST=all_suit

make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=2 TEST=all_suit

make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=3 TEST=all_suit

make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=4 TEST=all_suit

make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=5 TEST=all_suit
```

The default value of `TEST` is `all_suit`.

### Running All Supported Instruction Tests

`TEST=riscv_card` selects `bench_CPU/bin/tb_riscv_card.cpp`, based on
`99_doc/RISCV_CARD.pdf`. Run these commands in WSL/Bash from `bench_CPU`.
Requirements: Python 3, GNU `riscv64-unknown-elf-as`, `ld`, `objcopy`, and
`objdump` (all with the `riscv64-unknown-elf-` prefix), Verilator 5.x, Make,
and a C++ compiler. Adjust the Verilator path for your installation.

Run all instruction cases on the single-cycle CPU (mode 0):

```sh
make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=0 TEST=riscv_card
```

Run the same complete suite on **all six CPU modes**, including single-cycle
and every pipeline configuration:

```sh
failed=0
for mode in 0 1 2 3 4 5; do
    if ! make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE="$mode" TEST=riscv_card; then
        failed=1
    fi
done
test "$failed" -eq 0
```

The loop runs every mode even if an earlier mode fails. The final command
returns a nonzero status if any mode fails. To test one other CPU, use its
`CORE_MODE` value from the table above.

Each mode runs **84 cases**, covering all **37 implemented RV32I integer
instructions**, 33 compatible pseudoinstruction forms, boundary values, and
hazards. JALR checks include odd targets, positive/negative offsets, return
addresses, register aliasing, and a target supplied by a preceding load.
The card's **87 unsupported entries**, including extension instructions,
`ecall`, `ebreak`, and `fence`, are reported as `UNSUPPORTED`.
The expected per-mode result is **84 PASS, 0 FAIL, 87 UNSUPPORTED**.

`make test` generates the ROMs automatically. Per-case status and cycle counts
are written to `bench_CPU/results/riscv_card/mode0/results.csv` through
`mode5/results.csv`; rerunning a mode overwrites its CSV. The generated
`bench_CPU/tests/riscv_card/generated/instruction_coverage.csv` maps card
instructions to cases. See
[the instruction-test documentation](bench_CPU/tests/riscv_card/README.md)
for detailed coverage and the JALR regression.

Recorded results: [RV32I instruction checks for all six modes](bench_CPU/results/riscv_card/summary.md)
and [cycle comparison on `all_suit`](bench_CPU/results/all_suit_modes_2026-10-23/comparison.md).
These summary tables record the published run; the commands above update the
per-mode CSV files without regenerating the summary tables.

### Static Branch Prediction Checks

To check both static prediction policies, branch-target selection, and recovery
from both taken and not-taken mispredictions using `all_suit`, run:

```sh
make test-static-branch VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator
```

This check uses `CACHE=0` to exercise memory waits directly and requires
`g++-10` by default (`SIM_CXX` can select another C++20 compiler).

### Builds and Waveforms

`make test` builds the simulation if necessary and runs the selected test.
For the ROM tests such as `all_suit`, it also generates `wave_<test>.fst`.

Each core mode uses a separate build directory:

```text
obj_dir_mode0
obj_dir_mode1
obj_dir_mode2
obj_dir_mode3
obj_dir_mode4
obj_dir_mode5
```

The instruction suite uses separate `obj_dir_modeN_riscv_card` directories.
Tracing is off by default for that suite. To capture a waveform for each case
after building mode 0:

```sh
./obj_dir_mode0_riscv_card/Vtop riscv_card +MODE=0 +trace
```

Use the same mode number in the executable path and `+MODE` argument.

Open the waveform with:

```sh
make wave VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=3 TEST=all_suit
```

`gtkwave` must be installed to use the `wave` target.

Clean generated binaries, waveforms, and logs with:

```sh
make clean
```

### `all_suit` Regression

The `all_suit` test runs 14 verification conditions.

For the 32-bit cores, the expected result is:

```text
LEDR = 0x00003FFF
LEDG = 0x600D
```

For the `TOP_SYNTH` adapter, `LEDG` is only 9 bits wide, so the regression runner expects the corresponding value:

```text
LEDG = 0x00D
```

## Simulation in `10_sim`

Run the general simulation from the `10_sim` directory:

```sh
cd /home/lqhau/RISC-V-RV32i-master/10_sim

PATH=/home/lqhau/tools/oss-cad-suite/bin:$PATH make sim

PATH=/home/lqhau/tools/oss-cad-suite/bin:$PATH make run
```

`make sim` builds the testbench selected in `10_sim/flist`.

`make run` executes the generated simulation executable.

Use:

```sh
make wave
```

to open the waveform if GTKWave is installed.

## Quartus FPGA Project

The Altera Quartus project is located at:

```text
20_syn/altera/DE2-115
```

The project can be opened using:

```text
open_de2_115_gui.cmd
```

In Quartus, select:

**Processing > Start Compilation**

A launcher is also provided:

```text
build_de2_115_single_cycle.cmd
```

This script compiles the project and stores the logs, reports, and generated images under:

```text
builds/<timestamp>/
```

### DE2-115 FPGA Device

The current QSF configuration is set for:

```text
Cyclone II / EP2C35F672C6
```

with the DE2-115 pin assignment.

Make sure that the FPGA device on the physical board matches the configured device before programming the generated image.

Quartus 13.0.1 SP1 can successfully compile the project and generate the `.sof` file. However, TimeQuest currently reports a setup slack of:

```text
-9.162 ns
```

This indicates that the current design does not meet the configured timing constraint.

### SRAM Interface

The current wrapper selects:

```text
MEM_SRAM
```

However, the SRAM ports are currently left unconnected in the top-level design.

Therefore, the SRAM interface must be connected before expecting tests that use data memory to operate correctly on the physical board.

## DE10 Project

The directory:

```text
20_syn/altera/DE10/
```

is currently a scaffold for the DE10 project.

The exact DE10 board and FPGA device must be identified before adding the device configuration and pin assignments.

## Xilinx Project

The directory:

```text
20_syn/xilinx/
```

is reserved for Xilinx FPGA projects.
### Assembly and Binary Conversion

[RISC-V Venus](https://venus.cs61c.org/) can be used to assemble and inspect RISC-V assembly programs and generate the corresponding machine-code representation.

Use Venus when you need to verify the generated instructions before converting them into the ROM format used by this project.

# Computer Architecture

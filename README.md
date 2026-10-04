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

### Running Different Pipeline Stages

For example:

```sh
make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=1 TEST=all_suit

make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=2 TEST=all_suit

make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=3 TEST=all_suit
```

The default value of `TEST` is `all_suit`.

`make test` builds the simulation if necessary, runs the test, and generates a waveform file named `wave_<test>.fst`.

Each core mode uses a separate build directory:

```text
obj_dir_mode0
obj_dir_mode1
obj_dir_mode2
obj_dir_mode3
```

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

# Computer Architecture

# Milestone 1

Independent implementations for milestone-1.pdf v1.0 (2026-09-25).
Compile these files separately from the original CPU: both sets contain modules
named `alu` and `regfile`, with different interfaces. The active `10_sim/flist`
selects only this set and its testbench.

| Exercise | RTL | Behavior |
| --- | --- | --- |
| 1 | adder.sv | 32-bit ripple-carry addition/subtraction, bitwise datapath |
| 2 | magnitude_comparator.sv | Calls compare_operands() in cpu_pkg.sv for signed/unsigned comparison |
| 3 | shifter.sv | One shared five-stage mux network; reverse bits for left shifts |
| 4 | alu.sv | Exactly one adder, comparator and shifter instance; ten operations |
| 5 | regfile.sv | 32 registers, hardwired x0, asynchronous active-low reset, no bypass |
| 6 | data_mem_async.sv | Asynchronous read, synchronous byte-enabled writes |
| 7 (optional) | data_mem_sync.sv | Enabled registered read, read-before-write on simultaneous access |

ALU operation codes retain the existing CPU encoding: ADD=0, SUB=1, XOR=2,
OR=3, AND=4, SLL=5, SRL=6, SRA=7, SLT=8, SLTU=9. Codes 10..15 return zero.
The shifter returns zero for reserved mode 11.

The adder datapath does not use arithmetic + or -; comparator operand comparison
does not use relational operators; shifter datapath does not use shift operators.
Loop counters and constant bit-index calculations do not compare operand values.
Branch/magnitude comparison is implemented by the automatic package function
`compare_operands()`, returning `compare_result_t` with eq, lt and gt flags.
The comparator module exposes these flags through the lab interface; the ALU
continues to instantiate that module once for SLT and SLTU.

## Adder status convention

The PDF names o_cout but does not specify a precise signed-mode status equation.
This implementation explicitly chooses:

- Unsigned addition: raw carry out of bit 31.
- Unsigned subtraction: raw carry, 1 means no borrow (a >= b).
- Signed addition/subtraction: bit 32 of the sign-extended arithmetic result.

Signed o_cout is not a signed-overflow flag. The low 32-bit sum is the same
modulo 2^32 in both modes. The ALU only consumes o_sum.

## Memory choices

START_ADDR must be word-aligned; ADDR_WIDTH is 2..32 byte-address bits.
Addresses are checked in 33 bits so a region ending at 0x1_0000_0000 does not
wrap to address zero. Region size is 2^ADDR_WIDTH bytes. Each read returns the
containing word: address low bits do not rotate the word or byte mask.
Mask bit n enables wdata[8*n +: 8], with lane zero at the lowest byte address.
Out-of-range writes are ignored and enabled reads return zero.
The synchronous memory holds its output when i_rden is low, including when the
address is invalid. Simultaneous reads and writes return the old word.

Neither memory has a reset or implicit initialization, as specified by the lab.
Read values before initialization are unspecified. Initialize locations by writes
before checking them; the synchronous output is defined after its first enabled read.

## Simulation

Use Verilator 5.x and a C++ compiler in WSL/Linux. From the project root:

```sh
bash 01_bench/Milestone1/run.sh
bash 01_bench/Milestone1/run.sh +wave
```

The runner uses `10_sim/flist`, and puts build files, logs and optional waveform
under `02_test/Milestone1`. It stops on a lint, build or test failure.

The existing makefile also works from `10_sim`:

```sh
make lint
make sim SIM_CXX=g++
make run
```

The makefile retains its default build location `10_sim/obj_dir`. For a waveform
after that build, run `./obj_dir/Vtbench +wave`; the VCD is written into
`02_test/Milestone1/wave.vcd`.

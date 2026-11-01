# App 05: instruction sweep

Run separately in WSL from `10_sim`:

```sh
bash run_app05.sh
```

The console prints all 37 tested instructions and PASS/FAIL counts for each
requested CPU configuration. Reports are in `02_test/Milestone1/app05`, separate
from the normal CPU regression. For example,
`async_mode1/instructions.txt` contains the pipeline-stall async-memory table;
the root `instructions.tsv` combines all configurations.
The TSV report groups instructions as Arithmetic, Comparison, Bitwise, Shift,
Upper-immediate, Load, Store, Branch and Jump, within each core/configuration.
Fields are space-padded around real tab separators so the columns align in a
monospace text editor. `instructions.raw.tsv` contains the same grouped data
without padding for spreadsheet/data imports; JSON remains unformatted data.

Use `CORE_MODES=0 MEMORY_MODES=async COMPARE_BASELINE=0 bash run_app05.sh`
for only the replaced single-cycle core with async memory.
The normal `run_milestone1_cpu.sh` now defaults to `all_suit` alone.

Generate with `python 01_bench/Milestone1/generate_app05.py` from the project root.
The generator emits actual RV32I encodings without an assembler dependency:

- `app05_instruction.s`: readable assembly with resolved symbolic labels.
- `app05_instruction.mem`: the corresponding ROM image.
- `app05_manifest.json`: case IDs, instruction names, expected total and coverage.
- `app05_config.h`: the runner's exact expected LEDR and timeout.

The generated app has **63,724 checks**, **37 instruction mnemonics**, and
**2,120,604 bytes** of code. It is a simulation sweep, with a 4 MiB instruction
ROM in the generated CPU wrappers. It is not a board demo ROM.

| Domain | What is exhaustive | What is directed |
| --- | --- | --- |
| ADD/SUB/SLT/SLTU/XOR/OR/AND/SLL/SRL/SRA | All pairs of a documented 16-value set | Signed extrema, zero, alternating bits, boundaries |
| ADDI/SLTI/SLTIU/XORI/ORI/ANDI | All 4,096 signed 12-bit immediates for each mnemonic | One of 16 operand values selected per immediate |
| SLLI/SRLI/SRAI | All 32 amounts for all 16 data values | Sign fill and zero fill |
| SLL/SRL/SRA | All 32 amounts, 16 data values, three high-bit patterns in rs2 | Verify that only rs2[4:0] selects shift amount |
| LB/LBU/SB | All 4,096 signed byte offsets | Sign/zero extension and unchanged neighboring bytes |
| LH/LHU/SH | All 2,048 aligned signed halfword offsets | Both halfword lanes, sign/zero extension |
| LW/SW | All 1,024 aligned signed word offsets | Full-word readback |
| BEQ/BNE/BLT/BGE/BLTU/BGEU | All pairs of the 16-value set | Taken/not taken and a backward taken branch for each mnemonic |
| LUI/AUIPC | Not exhaustive over 20-bit immediates | Zero, extrema, all 20 walking-one values, exact AUIPC PC |
| Register roles | All 32 rd/rs1/rs2 indices in ADD; all 32 link destinations in JAL | x0 ignored writes, rd aliases rs1/rs2 |
| JAL/JALR | All 4,096 signed JALR immediates | Link value, wrong-path flush, JALR odd-target bit-zero clearing |

This does **not** exhaust all 2^64 operand pairs, all register-index tuples,
all 20-bit upper immediates, or all branch/jump displacements. FENCE, SYSTEM,
CSR, exceptions and misaligned data accesses are not implemented by this
project's decoder and are outside this app's claimed coverage.

`check_app05_model.py` independently decodes and executes the emitted ROM using
a simple Python RV32I model. It must reach all 63,724 checks before RTL testing.

Program protocol: PASS writes LEDR=0xf8ec then LEDG=0x600d. Failure writes its
case ID to LEDR, then LEDG=0x0bad. TOP_SYNTH exposes only nine LEDG bits, yielding
0x00d and 0x1ad respectively. The runner requires the exact appropriate width.
The final case explicitly observes JALR bit-zero clearing through AUIPC at the
target, so a PC alignment bug cannot hide behind instruction-word addressing.

## Independent GNU assembler verification

From `10_sim` in WSL, run `bash verify_app05_encoding.sh` with
`binutils-riscv64-linux-gnu` installed. This reads the existing .s and .mem files
without regenerating them. GNU as uses `-march=rv32i -mabi=ilp32 -mno-relax`;
GNU ld uses `-m elf32lriscv --no-relax -Ttext=0`. GNU objcopy extracts .text.
Each .mem word is separately converted to four little-endian bytes for comparison.

Verified: all 530,151 instruction words (2,120,604 bytes) match byte for byte,
with zero differing bytes and identical SHA-256 hashes. The report, raw binaries,
ELF, commands and a disassembly sample are in `encoding_check/`.
This checks every encoding in this particular ROM against an independent
assembler; CPU execution and test coverage remain separate verification steps.

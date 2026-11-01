# Full CPU app results

Each row is an actual ROM execution with a fresh model.

| Core | App | Blocks | Status | Cycles | Delta vs original | Matches original result |
| --- | --- | --- | --- | ---: | ---: | --- |
| 0 | app05_instruction | baseline | PASS | 774,100 | 0 | True |
| 0 | app05_instruction | async | PASS | 774,100 | 0 | True |
| 0 | app05_instruction | sync | PASS | 774,100 | 0 | True |
| 1 | app05_instruction | baseline | SELF_FAIL | 1,389,410 | 0 | True |
| 1 | app05_instruction | async | SELF_FAIL | 1,389,410 | 0 | True |
| 1 | app05_instruction | sync | SELF_FAIL | 1,389,410 | 0 | True |
| 2 | app05_instruction | baseline | SELF_FAIL | 659,112 | 0 | True |
| 2 | app05_instruction | async | SELF_FAIL | 659,112 | 0 | True |
| 2 | app05_instruction | sync | SELF_FAIL | 659,112 | 0 | True |
| 3 | app05_instruction | baseline | SELF_FAIL | 659,112 | 0 | True |
| 3 | app05_instruction | async | SELF_FAIL | 659,112 | 0 | True |
| 3 | app05_instruction | sync | SELF_FAIL | 659,112 | 0 | True |

Baseline equality does not imply PASS: the original CPU may fail the same app.

- Core 1 / baseline / app05_instruction: SELF_FAIL, LEDR=63724 (jalr: odd target must clear bit 0, observed through AUIPC).
- Core 1 / async / app05_instruction: SELF_FAIL, LEDR=63724 (jalr: odd target must clear bit 0, observed through AUIPC).
- Core 1 / sync / app05_instruction: SELF_FAIL, LEDR=63724 (jalr: odd target must clear bit 0, observed through AUIPC).
- Core 2 / baseline / app05_instruction: SELF_FAIL, LEDR=63724 (jalr: odd target must clear bit 0, observed through AUIPC).
- Core 2 / async / app05_instruction: SELF_FAIL, LEDR=63724 (jalr: odd target must clear bit 0, observed through AUIPC).
- Core 2 / sync / app05_instruction: SELF_FAIL, LEDR=63724 (jalr: odd target must clear bit 0, observed through AUIPC).
- Core 3 / baseline / app05_instruction: SELF_FAIL, LEDR=63724 (jalr: odd target must clear bit 0, observed through AUIPC).
- Core 3 / async / app05_instruction: SELF_FAIL, LEDR=63724 (jalr: odd target must clear bit 0, observed through AUIPC).
- Core 3 / sync / app05_instruction: SELF_FAIL, LEDR=63724 (jalr: odd target must clear bit 0, observed through AUIPC).

App 05: 63,724 checks, 37 instructions, 2,120,604 ROM bytes.
Coverage: 37 implemented RV32I instructions; exhaustive 12-bit ALU/JALR immediates, aligned load/store offsets, all 5-bit shifts; directed 32-bit operands/register roles/branches/U-type immediates. Not all 32-bit operand tuples; excludes unsupported FENCE/SYSTEM/traps and misaligned data accesses.

PASS requires the exact app signature in LEDR and exact core-width status in LEDG before timeout.
Modes 0..2: PASS=0x600d, SELF_FAIL=0x0bad. Mode 3: PASS=0x00d, SELF_FAIL=0x1ad.
all_suit LEDR=0x3fff; app05 LEDR=0xf8ec.
Missing ROM, lint/build errors, timeout, any other LEDG, or incorrect LEDR are failures.
The program writes LEDR first and LEDG last. These conditions are identical for async and sync memory.

## Failure diagnosis

All observed app failures are the final JALR odd-target case. The single-cycle
CPU clears bit 0; the pipeline PC_EX_ALU path in 00_src/rv32i.sv assigns
EX_alu_res directly to pc. The instruction ROM discards low address bits, so
AUIPC at the target is used to expose the incorrect odd PC. This failure
occurs in the original baseline and in both replacement-memory configurations.
The old pipeline PC logic is unchanged by this task.

LEDR=0xf8ec is both the success signature and the last case ID. LEDG=0x0bad
(or 0x1ad in mode 3) still means SELF_FAIL, regardless of matching LEDR.

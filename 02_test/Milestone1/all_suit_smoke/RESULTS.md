# Full CPU app results

Each row is an actual ROM execution with a fresh model.

| Core | App | Blocks | Status | Cycles | Delta vs original | Matches original result |
| --- | --- | --- | --- | ---: | ---: | --- |
| 0 | all_suit | async | PASS | 84,475 | not run | None |

Baseline equality does not imply PASS: the original CPU may fail the same app.


App 05: 63,724 checks, 37 instructions, 2,120,604 ROM bytes.
Coverage: 37 implemented RV32I instructions; exhaustive 12-bit ALU/JALR immediates, aligned load/store offsets, all 5-bit shifts; directed 32-bit operands/register roles/branches/U-type immediates. Not all 32-bit operand tuples; excludes unsupported FENCE/SYSTEM/traps and misaligned data accesses.

PASS requires the exact app signature in LEDR and exact core-width status in LEDG before timeout.
Modes 0..2: PASS=0x600d, SELF_FAIL=0x0bad. Mode 3: PASS=0x00d, SELF_FAIL=0x1ad.
all_suit LEDR=0x3fff; app05 LEDR=0xf8ec.
Missing ROM, lint/build errors, timeout, any other LEDG, or incorrect LEDR are failures.
The program writes LEDR first and LEDG last. These conditions are identical for async and sync memory.

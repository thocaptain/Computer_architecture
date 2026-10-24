# RISCV_CARD instruction tests

Source: `99_doc/RISCV_CARD.pdf`, pages 1-4. The card covers more ISA extensions
than the current RV32I implementation. This suite reports that distinction:

| Card group | Treatment |
| --- | --- |
| 37 implemented RV32I integer instructions | Executed and checked |
| RV32I `ecall`, `ebreak` | UNSUPPORTED: no trap/environment implementation |
| 33 RV32I-compatible pseudoinstruction forms | Assembled to RV32I and checked |
| M, A, F/D, C, RV64-only/FP pseudo forms, `fence` | UNSUPPORTED |

There are **84 executable cases** and **87 unsupported card entries**. An
unsupported entry is documented, not executed, and never counted as PASS.
The card's `mulsu`/`mulu` spellings are listed with their GNU equivalents
`mulhsu`/`mulhu`. Only entries actually listed on the card are inventoried;
this is not a complete modern ISA compliance suite.

## Run

From WSL in `bench_CPU`:

```sh
make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=0 TEST=riscv_card
```

Select `CORE_MODE=0..5` for any current CPU configuration. To run all modes and
continue collecting results even when a mode fails:

```sh
for mode in 0 1 2 3 4 5; do
    make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE="$mode" TEST=riscv_card
done
```

Requirements: Python 3, GNU `riscv64-unknown-elf-{as,ld,objcopy,objdump}`,
Verilator and a C++ compiler. PDF extraction is not needed to run the tests.

`generate.py` uses `-march=rv32i -mabi=ilp32`, disables compressed instructions
and linker relaxation, and creates one self-checking ROM per case. Every ROM
is checked against the 1024-byte instruction-memory limit and padded to exactly
256 words. `.s`, `.elf`, `.dis`, `.bin`, and `.mem` artifacts are available in
`generated/`, along with:

- `manifest.tsv`: executable cases and unsupported entries.
- `instruction_coverage.csv`: mapping from each card instruction/form to tests.

The generator also checks the real disassembly for all 37 base instructions.
The generated directory is ignored by Git and rebuilt by `make test`.

## Checks

- ADD/SUB overflow wraparound, zero and signed extrema; Boolean operations.
- Signed/unsigned SLT and branch comparisons; negative immediate extension.
- Every immediate/register shift amount 0-31, plus register shift masking.
- Every byte and aligned halfword lane, signed/unsigned loads, partial-store
  preservation, word access, and positive/negative address offsets.
- Each conditional branch taken and not taken, forward and backward targets.
- JAL/JALR target and link addresses; JALR target bit-zero clearing after
  `rs1 + imm`, positive/negative immediates, `rd == rs1`, `rd == x0`, and
  a jump target supplied by an immediately preceding load.
- AUIPC at nonzero PCs, positive/negative upper immediates, and LUI extrema.
- x0 invariance, RAW dependencies, load-use/store forwarding, wrong-path side
  effects and conflicting cache-line eviction.
- RV32I-compatible pseudo arithmetic, branches, symbolic loads/stores, address
  construction, jumps, calls, returns and tail calls.

The new C++ testbench is `bin/tb_riscv_card.cpp`. It uses public CPU/MMIO pins
through `bin/top.sv`, loads each ROM with `+PROG`, constructs a fresh model for
each case, and checks the program's result. The simulation-only `DV` path in
`inst_mem.sv` honors `+PROG`; the FPGA/default ROM path remains available.

Each ROM writes its case ID to LEDR and `0x600D` to LEDG on success. A failure
writes the check number to LEDR and `0x0BAD` to LEDG. Mode 3 exposes only 9 LEDG
bits, so its expected status is masked accordingly. Missing images or malformed
manifests are errors; failed/timed-out tests make the command exit nonzero.

Results are written to `results/riscv_card/modeN/results.csv`. Cycle counts
include each case's setup, checks, and two reset-loop cycles; these totals are
test-harness measurements, not a standalone application performance benchmark.
Tracing is off by default. After building, add `+trace` when directly running
`obj_dir_modeN_riscv_card/Vtop riscv_card +MODE=N` to save per-case FST files.

## JALR regression

`jalr_odd_target` originally failed on pipeline modes 1-5: the core assigned the
unmasked ALU result to PC for JALR. The pipeline now clears bit zero specifically
for JALR when updating PC. Branch targets retain their existing calculation,
and the JALR link value remains the instruction's `PC + 4`.

The case checks odd targets produced by the base register or immediate, a
negative immediate, and an odd base plus an odd immediate whose sum is even.
AUIPC at each destination checks the actual PC because instruction-memory
indexing otherwise hides the low address bit. The saved return address is
checked independently for every jump. The regular `jalr` case also checks
register aliasing, discarded links, and a load-use dependency on the target.

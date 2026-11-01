# Milestone 1 verification data and results

`datapath_vectors.txt` contains directed operand pairs in hexadecimal (a b).
The testbench also uses a fixed-seed xorshift generator for reproducibility.
Reference arithmetic/comparison/shift operators are used only in the testbench.

Coverage:

- Directed signed extrema, zero, equality, carry, borrow and ALU shift masking.
- 1,024 generated operand pairs; signed/unsigned add/sub, comparison one-hot,
  all ten ALU operations and all six unused operation codes.
- All 32 shift amounts in all four modes for each directed first operand.
- All 32 register addresses on both ports, x0 writes, write disable, no bypass,
  and asynchronous reset after registers contain nonzero data.
- All 16 masks and four byte offsets; first/last valid and invalid addresses,
  ignored invalid writes, enabled synchronous reads, disabled-read hold,
  read-before-write, and 512 generated memory accesses checked against a model.
- ADDR_WIDTH=2 and a one-word memory at 0xffff_fffc, including no address wrap.

Run `bash 01_bench/Milestone1/run.sh` from the project root. Generated logs:
`tool_version.log`, `lint.log`, `build.log`, and `results.log`. A passing run ends
with `MILESTONE1 PASS`. With `+wave`, `wave.vcd` is also generated here.

Full CPU integration is separate: run `bash 10_sim/run_milestone1_cpu.sh` from
the project root. Logs and summaries are written under `cpu/`, comparing the
original blocks against Milestone1 async/sync replacements in all four core modes.
See `00_src/Milestone1/cpu/README.md` for the adapters and scope.

App 05 runs separately with `bash 10_sim/run_app05.sh`; per-instruction PASS/FAIL
tables and individual app logs are in `app05/`. The combined per-instruction
table is `app05/instructions.tsv`. Normal CPU regression defaults to all_suit.

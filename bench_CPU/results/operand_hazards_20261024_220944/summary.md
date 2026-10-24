# Operand-aware RAW and forwarding regression

All six CPU modes pass the 84-case instruction suite and all_suit (14 checks).
These builds retain their original internal cache and memory-latency configuration.

The change in `00_src/rv32i.sv` checks whether each instruction actually reads
rs1/rs2 before detecting RAW dependencies or selecting EX forwarding. Branches
and stores retain their register dependencies; JALR still reads rs1.

`riscv_card` covers the 37 implemented RV32I instructions, compatible pseudo
instructions, and edge cases. Each mode reports 84 PASS, 0 FAIL, and 87 UNSUPPORTED
card entries. This is the local bench_CPU suite, not the TA server compliance test.
Its cycle count is the sum across the 84 separate test programs.

Modes: 0 single cycle, 1 pipeline stall, 2 pipeline with forwarding, 3 full
pipeline/TOP_SYNTH, 4 not always jump, 5 always jump.

| Mode | Test | Passed | Failed | Cycles before | Cycles after | Saved |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 0 | riscv_card | 84 | 0 | 4468 | 4468 | 0 |
| 0 | all_suit | 14 | 0 | 84475 | 84475 | 0 |
| 1 | riscv_card | 84 | 0 | 12438 | 12306 | 132 |
| 1 | all_suit | 14 | 0 | 56915 | 56906 | 9 |
| 2 | riscv_card | 84 | 0 | 8079 | 8079 | 0 |
| 2 | all_suit | 14 | 0 | 37193 | 37193 | 0 |
| 3 | riscv_card | 84 | 0 | 8079 | 8079 | 0 |
| 3 | all_suit | 14 | 0 | 34317 | 34317 | 0 |
| 4 | riscv_card | 84 | 0 | 8079 | 8079 | 0 |
| 4 | all_suit | 14 | 0 | 37193 | 37193 | 0 |
| 5 | riscv_card | 84 | 0 | 8091 | 8091 | 0 |
| 5 | all_suit | 14 | 0 | 36307 | 36307 | 0 |

Baseline: `../control_redirect_20261024_115622/summary.csv` for modes 1-5;
`../all_suit_modes_2026-10-23/comparison.csv` and `../riscv_card/summary.csv` for mode 0.
Raw execution output and build logs are kept locally beside this report and
ignored by Git. All twelve
build/run combinations completed successfully with the OSS CAD Suite Verilator.

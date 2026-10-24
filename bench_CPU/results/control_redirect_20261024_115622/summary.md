# Original workspace regression after shared hazard fix

All five pipeline modes pass the 84-case instruction suite and all_suit (14 checks).
These builds retain their original internal cache and memory-latency configuration.

| Mode | Test | Passed | Failed | Harness cycles |
| --- | --- | ---: | ---: | ---: |
| 1 | riscv_card | 84 | 0 | 12438 |
| 1 | all_suit | 14 | 0 | 56915 |
| 2 | riscv_card | 84 | 0 | 8079 |
| 2 | all_suit | 14 | 0 | 37193 |
| 3 | riscv_card | 84 | 0 | 8079 |
| 3 | all_suit | 14 | 0 | 34317 |
| 4 | riscv_card | 84 | 0 | 8079 |
| 4 | all_suit | 14 | 0 | 37193 |
| 5 | riscv_card | 84 | 0 | 8091 |
| 5 | all_suit | 14 | 0 | 36307 |

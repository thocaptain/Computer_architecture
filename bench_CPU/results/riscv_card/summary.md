# RISCV_CARD test results after the JALR fix

Run date: 2026-10-23 (Asia/Saigon). Source: 99_doc/RISCV_CARD.pdf.
84 executable cases cover all 37 implemented RV32I integer instructions, 33 compatible pseudo forms, and edge/hazard cases. 87 unsupported card entries are explicitly listed per mode and are not counted as PASS.

| Mode | CPU | PASS | FAIL | UNSUPPORTED | Harness cycles |
| --- | --- | ---: | ---: | ---: | ---: |
| 0 | TOP_SINGLE_CYCLE | 84 | 0 | 87 | 4468 |
| 1 | rv32i_pipeline_stall | 84 | 0 | 87 | 12438 |
| 2 | rv32i_pipeline_hazard | 84 | 0 | 87 | 8079 |
| 3 | TOP_SYNTH | 84 | 0 | 87 | 8079 |
| 4 | rv32i_not_always_jump | 84 | 0 | 87 | 8079 |
| 5 | rv32i_always_jump | 84 | 0 | 87 | 8091 |

The previous jalr_odd_target failure was reproduced before the fix on mode 2; see jalr_before_fix.log. The pipeline now clears target bit zero after computing rs1 + immediate, specifically on JALR PC updates. Ordinary branch targets and the saved return address PC+4 retain their existing calculation.

The existing jalr and jalr_odd_target cases were strengthened without changing the number of cases. They check:

- Odd targets from the base register or a positive/negative immediate, and an odd base plus an odd immediate whose sum is even.
- The actual target PC via AUIPC, and PC+4 return addresses independently.
- Positive and negative offsets, rd==rs1, rd==x0, and a load-use dependency on the jump target.
- The existing pseudo jr, jalr, ret, call and tail cases also pass in every mode.

Harness cycles include setup, result checking, MMIO reporting, and separate resets for every case. The cases now perform more checks, so their totals should not be compared to earlier card-suite totals as a performance improvement. Mode 0 has cache disabled; pipeline modes have cache enabled.

Reproduce from bench_CPU:

```sh
make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=1 TEST=riscv_card
```

Use CORE_MODE=0..5. Per-case CSV files are under modeN/results.csv; generated assembly, ROMs, disassembly, coverage and the manifest are under tests/riscv_card/generated/.

Existing all_suit regression after the JALR fix:

| Mode | Result | Cycles |
| --- | --- | ---: |
| 1 | PASS | 56915 |
| 2 | PASS | 37193 |
| 3 | PASS | 34317 |
| 4 | PASS | 37193 |
| 5 | PASS | 36307 |

The all_suit cycle counts match the earlier runs before this fix. Raw logs are stored as regression_modeN_all_suit.log.

Static branch-policy regression: both not-taken and taken checks PASS, including both misprediction recovery paths. See regression_static_branch.log.

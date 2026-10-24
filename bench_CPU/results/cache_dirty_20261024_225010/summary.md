# Cache dirty-bit regression

All six CPU modes pass all_suit (14 checks) and the local riscv_card ISA suite (84 PASS, 0 FAIL, 87 UNSUPPORTED per mode). The ISA cycle count sums 84 separate programs; this is not the TA server compliance suite.

Baseline: ../operand_hazards_20261024_220944/summary.csv. The operand-aware RAW/forwarding change remains enabled. Mode 0 has no cache; modes 1-5 retain the 512-byte direct-mapped cache (8 lines, 16 words per line) and the original main-memory latency.

| Mode | Test | Passed | Failed | Cycles before | Cycles after | Saved | Reduction |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | riscv_card | 84 | 0 | 4468 | 4468 | 0 | 0.0% |
| 0 | all_suit | 14 | 0 | 84475 | 84475 | 0 | 0.0% |
| 1 | riscv_card | 84 | 0 | 12306 | 12146 | 160 | 1.3% |
| 1 | all_suit | 14 | 0 | 56906 | 56906 | 0 | 0.0% |
| 2 | riscv_card | 84 | 0 | 8079 | 7919 | 160 | 1.98% |
| 2 | all_suit | 14 | 0 | 37193 | 37193 | 0 | 0.0% |
| 3 | riscv_card | 84 | 0 | 8079 | 7919 | 160 | 1.98% |
| 3 | all_suit | 14 | 0 | 34317 | 34317 | 0 | 0.0% |
| 4 | riscv_card | 84 | 0 | 8079 | 7919 | 160 | 1.98% |
| 4 | all_suit | 14 | 0 | 37193 | 37193 | 0 | 0.0% |
| 5 | riscv_card | 84 | 0 | 8091 | 7931 | 160 | 1.978% |
| 5 | all_suit | 14 | 0 | 36307 | 36307 | 0 | 0.0% |

Modes: 0 single cycle; 1 pipeline stall; 2 pipeline forwarding; 3 full pipeline/TOP_SYNTH; 4 not always jump; 5 always jump.

Per-case ISA CSVs are published beside this report. Raw build/run logs are kept
locally and ignored by Git. Cycle reductions are measured in simulation and do
not establish a higher clock frequency.

The separate `make test-cache-dirty` regression also passes. It checks clean
eviction without write-back, dirty eviction with data preserved, dirty read
hits, masked stores, store misses, and clearing dirty after refill against a
delayed memory model. See `cache_check.txt` and `01_bench/cache_dirty/tbench.sv`.

For modes 1-5 the ISA reduction is entirely in
`cache_eviction_preserves_stores`: a clean-line replacement skips one 16-word
write-back, saving 160 cycles with the existing memory latency. All other ISA
cases keep their cycle counts. The all_suit program has no measured cycle
reduction from this change.

# Shared pipeline hazard-priority regression

The same EX-redirect priority is present in pipeline source modes 1-5 and in the original workspace hazard_ctrl.sv.
The forwarding and prediction settings of each mode are preserved.

| Mode | JALR vectors | Branch vectors per instruction | Minimal cases | Status |
| --- | ---: | ---: | ---: | --- |
| 1 | 4096 | 7094 for each of BEQ/BNE/BLT/BGE/BLTU/BGEU | 7 | PASS |
| 2 | 4096 | 7094 for each of BEQ/BNE/BLT/BGE/BLTU/BGEU | 7 | PASS |
| 3 | 4096 | 7094 for each of BEQ/BNE/BLT/BGE/BLTU/BGEU | 7 | PASS |
| 4 | 4096 | 7094 for each of BEQ/BNE/BLT/BGE/BLTU/BGEU | 7 | PASS |
| 5 | 4096 | 7094 for each of BEQ/BNE/BLT/BGE/BLTU/BGEU | 7 | PASS |

- Mode 1: [results](../mode1_control_flow/20261024_113958_after_fix/results.csv)
- Mode 2: [results](20261024_115623_mode2_shared_fix/results.csv)
- Mode 3: [results](20261024_115623_mode3_shared_fix/results.csv)
- Mode 4: [results](20261024_115644_mode4_shared_fix/results.csv)
- Mode 5: [results](20261024_115645_mode5_shared_fix/results.csv)

Each mode passes 46,660 stress vectors plus seven minimal redirect/RAW-collision cases.
These are recreated student vectors, not the official TA binaries.

[84-case instruction and all_suit regression](../cpu_modes/regression_20261024_115519/summary.md) also passes in all modes.
The retirement-PC sequences match the single-cycle baseline exactly.

Run from the template root in WSL:

    python3 01_bench/student_mode1_control_flow/run.py --mode 2 --suite stress --label check

Select --mode 1 through --mode 5; use --suite smoke for the seven minimal cases.
The runner uses local GNU RISC-V binutils, Verilator 5.x and g++-10.

The original workspace additionally has make test-control-redirect in bench_CPU,
covering 14 hazard-controller scenarios, including older MEM waits and WB-forward preservation.

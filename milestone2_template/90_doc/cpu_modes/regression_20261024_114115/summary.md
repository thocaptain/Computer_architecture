# External-memory CPU modes: regression results

Simulator: Verilator 5.053. PC reset: 0x80000000; data: 0x80080000.
Each run uses the actual IMEM/DMEM source files from its source folder.

| Mode | Source folder | Instruction cases | all_suit | all_suit cycles | Retired instructions | Trace |
| --- | --- | --- | --- | ---: | ---: | --- |
| 0 | `00_src` | 84/84 PASS | PASS (14/14) | 24263 | 24263 | MATCH |
| 1 | `00_src_mode1_pipeline_stall` | 84/84 PASS | PASS (14/14) | 55305 | 24263 | MATCH |

Cycles exclude two reset cycles and end when the final result store retires.
Pipeline measurements include filling the pipeline and all hazard/prediction bubbles.
The pipeline retirement-PC sequence must match the single-cycle baseline exactly
for every instruction test and all_suit; inserted flush NOPs are excluded.
Source modes share asynchronous memory without cache or artificial memory latency.
The 84 instruction cases are rebased copies of the student RISCV_CARD regression.
all_suit is the prior C-map ROM with only its four address LUIs changed.
These are student regressions; the official TA testbench and programs are unavailable.

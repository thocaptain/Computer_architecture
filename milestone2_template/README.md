# CPU sources for the Milestone 2 external-memory interface

This directory publishes the student sources developed in the F: template.
The TA infrastructure is not included: obtain milestone2.sv, the official
testbench/programs and the 03_sim Makefile from the course template.

| Mode | Source directory |
| --- | --- |
| 0 | [00_src](00_src) (single-cycle) |
| 1 | [00_src_mode1_pipeline_stall](00_src_mode1_pipeline_stall) |
| 2 | [00_src_mode2_pipeline_hazard](00_src_mode2_pipeline_hazard) |
| 3 | [00_src_mode3_full_pipeline](00_src_mode3_full_pipeline) |
| 4 | [00_src_mode4_not_always_jump](00_src_mode4_not_always_jump) |
| 5 | [00_src_mode5_always_jump](00_src_mode5_always_jump) |

Select one source directory as 00_src in a separate course-template copy.
All variants retain the singlecycle port names for wrapper compatibility;
modes 1-5 are pipeline architectures. Compile rv32i_pkg.sv before its users.
IMEM uses 32-bit words, so select IMEM_FORMAT=4B. PC resets to 0x80000000.
The memories match the simplified original student implementations and index
the low address bits. They assume the aligned memory maps in the document;
START_ADDR is retained as a template parameter without range checking.
External DMEM has asynchronous reads, byte-enabled edge writes, no cache
and no artificial memory latency.

## Fix and validation

The hazard controller prioritizes EX branch/JALR redirects over younger ID
RAW stalls, while preserving waits for older memory transactions.

- [Original mode-1 failure and before/after proof](90_doc/mode1_control_flow/README.md)
- [All-mode JALR/branch stress results](90_doc/control_flow_modes/README.md)
- [84-case instruction and all_suit regression](90_doc/cpu_modes/regression_20261024_115519/summary.md)
- [Mode selection and ordered source lists](90_doc/cpu_modes/README.md)

Run the recreated student stress tests from this directory under WSL:

```sh
python3 01_bench/student_mode1_control_flow/run.py --mode 1 --suite stress --label check
```

Select --mode 1 through --mode 5. The runner uses GNU RISC-V binutils,
Verilator 5.x and g++-10; adjust its local OSS CAD Suite path as needed.
Each mode passes 4096 JALR vectors, 7094 vectors for each of six branch
instructions, seven minimal reproducers, the existing 84 instruction cases
and all_suit (14 checks). These are student regressions, not official TA results.

Large generated stress assembly/ROMs, build files and RTL snapshots are omitted
from Git. The maintained runner recreates the vectors; summary tables, selected
simulation logs and small reproducers are included. Older reports may refer
to additional artifacts available only in the local F: workspace.
The original ALU/controller constructs and strict illegal-encoding validation
remain separate compliance work for the course specification.

# Alternative CPU sources for the external-memory template

`00_src` remains the single-cycle implementation (mode 0).

| Mode | Source folder | CPU configuration |
| --- | --- | --- |
| 1 | `00_src_mode1_pipeline_stall` | `rv32i_pipeline_stall` |
| 2 | `00_src_mode2_pipeline_hazard` | `rv32i_pipeline_hazard` |
| 3 | `00_src_mode3_full_pipeline` | `rv32i_full_pipeline` |
| 4 | `00_src_mode4_not_always_jump` | `rv32i_not_always_jump` |
| 5 | `00_src_mode5_always_jump` | `rv32i_always_jump` |

Each folder is self-contained and exports the same TA `singlecycle` ports.
Use one source folder at a time as `00_src` in a separate template copy.
The module name `singlecycle` is retained for wrapper compatibility; modes 1-5
are pipeline architectures, so the Milestone 2 single-cycle IPC requirement does not apply to them.
Do not combine these source folders into one HDL file list: module names repeat.
`modeN.f` lists the compile order with paths relative to `03_sim`;
add the course wrapper/testbench files separately when using a custom file list.
These files do not modify the provided TA makefile or infrastructure.

All modes reset PC to `0x80000000` and use the same 32-bit-word IMEM
and byte-enabled DMEM copied from mode 0. Select `IMEM_FORMAT=4B`.
The memory interface is asynchronous, without cache or artificial memory latency.
Mode 3 uses forwarding and tournament prediction from the original `TOP_SYNTH` core,
with the FPGA peripheral wrapper replaced by the TA-compatible port wrapper.
Mode 4 shares the same core settings as mode 2.
Mode 5 predicts taken on a BTB hit and PC+4 on a cold miss.

`o_db_valid` reports retirement at WB. An IF/ID occupancy bit keeps inserted
NOP bubbles out of that count while preserving fetched architectural NOPs.
Original functional-unit code and the pipeline JALR target-bit fix are retained.
Original RTL operator/function restrictions and strict illegal-instruction validation
remain separate from this interface adaptation. Official TA tests are not present locally.

## Validation

[Regression results](regression_20261024_112227/summary.md) include all six modes:
84/84 student instruction cases and all_suit (14/14 checks) PASS for every mode.
The pipeline retirement-PC trace matches the single-cycle reference exactly.
Per-test CSV files, build/run logs and RTL fingerprints are stored with the report.

Mode 1 was subsequently fixed for an EX redirect colliding with a younger ID RAW
stall. See the [control-flow failure reproductions and fix](../mode1_control_flow/README.md)
and [mode-0/mode-1 regression after that fix](regression_20261024_114115/summary.md).

The priority rule is now synchronized across all five pipeline source folders
and the original workspace. See the [all-mode control-flow regression](../control_flow_modes/README.md)
and [instruction/all_suit regression for the shared fix](regression_20261024_115519/summary.md).

# Mode 1: JALR and branch redirect regression

The reported server groups were JALR.TARGET and BEQ/BNE/BLT/BGE/BLTU.COMPARE.
The TA testbench and binaries are unavailable locally. These are student-created
reproducers and stress vectors for those instruction behaviors, including BGEU.
Matching vector counts do not imply the same vectors as the TA suite.

## Confirmed cause and change

In stall-only mode, the RAW detector checks dependencies against EX, MEM and WB.
When a branch or JALR redirects in EX, its younger instruction in ID may report
a dependency on one of those stages. The old hazard controller ANDed that ID
stall into PC/IF-ID enables. This suppressed the PC redirect and prevented the
wrong-path instruction from being flushed while the branch/JALR left EX.

The initial fix changed `00_src_mode1_pipeline_stall/hazard_ctrl.sv`. An EX branch
recovery/JALR now overrides a younger ID RAW stall once the older MEM stage is
ready. Existing flush signals discard the wrong-path instruction. This keeps
the stall-only architecture; forwarding is still disabled.

The same rule was subsequently synchronized to pipeline modes 2-5 and the
original workspace hazard controller. The [all-mode results](../control_flow_modes/README.md)
cover the shared fix. This does not change each mode's forwarding/prediction configuration.

Small reproducer patterns:

```asm
# JALR writes ra; its wrong-path successor reads ra.
jalr ra, 0(t0)
addi t3, ra, 0
```

```asm
# Branch operands are already available. An older write is pending in MEM;
# the wrong-path instruction reads its destination.
addi t0, zero, 1
beq t1, t2, target
addi t3, t0, 0
```

The before-fix log records `REDIRECT_AND_ID_STALL ... pc_en=0`.

## Before/after results

| Recreated group | Vectors | Before | After |
| --- | ---: | --- | --- |
| JALR_TARGET | 4096 | FAIL, first case 1 | PASS |
| BEQ_COMPARE | 7094 | FAIL, first case 1 | PASS |
| BNE_COMPARE | 7094 | FAIL, first case 2 | PASS |
| BLT_COMPARE | 7094 | FAIL, first case 3 | PASS |
| BGE_COMPARE | 7094 | FAIL, first case 1 | PASS |
| BLTU_COMPARE | 7094 | FAIL, first case 25 | PASS |
| BGEU_COMPARE | 7094 | FAIL, first case 1 | PASS |
| Minimal redirect/stall reproducers | 7 | 7 FAIL | 7 PASS |

The fixed source passes 46,660 stress vectors and seven minimal reproducers.
JALR vectors span every signed 12-bit immediate, odd/even effective targets,
multiple source/destination registers, rd==rs1, rd==x0, loaded jump targets,
link values and actual target PC (via AUIPC). Branch vectors combine signed
and unsigned edge/random operands, x0 and equal source registers, taken/not-taken
paths and dependencies on pending ALU/load writes.

- [Before-fix stress results](20261024_114115_before_stress_snapshot/results.csv)
- [After-fix stress results](20261024_113958_after_fix/results.csv)
- [Original minimal failure logs and RTL snapshot](20261024_113907_before_confirm/)
- [Existing instruction/all_suit regression after the fix](../cpu_modes/regression_20261024_114115/summary.md)

The existing 84/84 instruction cases and all_suit (14/14) also PASS. Mode 1
still takes 55,305 active cycles through final-result retirement for all_suit.
All retirement-PC traces match the single-cycle reference.

## Reproduce locally

From the template root under WSL, with GNU RISC-V binutils, Verilator 5.x and
g++-10 installed (the runner currently uses the local OSS CAD Suite path):

```sh
python3 01_bench/student_mode1_control_flow/run.py --suite stress --label check
```

Each new run saves assembly, ROMs, logs, a source snapshot and results.csv under
`90_doc/control_flow_modes/`. Historical before/after reports remain in
`90_doc/mode1_control_flow/`. `--suite smoke` selects the seven minimal cases.
`--mode 1..5` selects another pipeline configuration.
Use `--source /path/to/rtl_snapshot` to verify an older source snapshot.

After updating the server copy of the mode-1 source, rerun the official suite
from its `03_sim` directory:

```sh
make sim TEST=ISA_TEST IMEM_FORMAT=4B WAVE=NONE
```

# CPU mode cycle comparison

Date: 2026-10-23 (Asia/Saigon). Benchmark: all_suit (14 checks).

Verilator: /home/lqhau/tools/oss-cad-suite/bin/verilator (5.053 devel).
Each mode was rebuilt as needed from current sources, then run from bench_CPU with ./obj_dir_modeN/Vtop all_suit. Waveform tracing was disabled for these runs.
Cycles are the existing runner count through the pass/fail LEDG write, including its two reset-loop cycles.
Mode 0 uses CACHE=0; modes 1-5 use CACHE=1. All use MEM_FLOP and INST_MEM_ADDR_W=10.

| Mode | Core | Cache | Status | Cycles | Speedup vs mode 0 | LEDR | LEDG |
| --- | --- | --- | --- | ---: | ---: | --- | --- |
| 0 | TOP_SINGLE_CYCLE | 0 | PASS | 84475 | 1 | 0x00003FFF | 0x600D |
| 1 | rv32i_pipeline_stall | 1 | PASS | 56915 | 1.4842 | 0x00003FFF | 0x600D |
| 2 | rv32i_pipeline_hazard | 1 | PASS | 37193 | 2.2713 | 0x00003FFF | 0x600D |
| 3 | TOP_SYNTH | 1 | PASS | 34317 | 2.4616 | 0x00003FFF | 0xD |
| 4 | rv32i_not_always_jump | 1 | PASS | 37193 | 2.2713 | 0x00003FFF | 0x600D |
| 5 | rv32i_always_jump | 1 | PASS | 36307 | 2.3267 | 0x00003FFF | 0x600D |

Speedup is mode-0 cycles / mode-N cycles, assuming an equal clock period. These cycle counts alone do not measure FPGA execution time or isolate the effect of pipelining because cache configurations differ.
Modes 2 and 4 intentionally share the same core configuration.
Mode 5 predicts taken on a BTB hit and follows PC+4 on a cold miss. Mode 3 uses tournament prediction through the board wrapper, which exposes only the low 9 bits of LEDG.

Per-mode build and simulation logs are stored beside this report.

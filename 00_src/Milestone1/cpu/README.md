# Milestone1 blocks in the complete CPU bench

Run from the project root in WSL/Linux with Verilator 5.x, Python 3 and g++:

```sh
bash 10_sim/run_milestone1_cpu.sh
```

The script derives simulation wrappers from `bench_CPU/bin/top.sv` and uses
`01_bench/Milestone1/cpu_runner.cpp`. By default it runs only `all_suit`.
Defaults: all four CORE_MODE values, baseline plus Milestone1 asynchronous memory
and Milestone1 synchronous memory (12 configurations, 12 all_suit runs).
Every run uses its own fresh VerilatedContext/model and program initialization.
The script returns nonzero if any lint, build or simulation fails.
It also compares status, cycles, LEDR and LEDG against each original-core baseline.
A matching failure is reported as a failure, never converted into a PASS.

To run only the single-cycle CPU with the asynchronous lab memory:

```sh
CORE_MODES=0 MEMORY_MODES=async bash 10_sim/run_milestone1_cpu.sh
```

To omit the original-block baseline:

```sh
COMPARE_BASELINE=0 bash 10_sim/run_milestone1_cpu.sh
```

App 05 has its own entry point, run from `10_sim`:

```sh
bash run_app05.sh
```

It runs only `app05_instruction` and prints all 37 instruction names with
PASS/FAIL, planned cases, passed cases, failed cases and incomplete cases for
each configuration. Results are separate in `02_test/Milestone1/app05`;
simulation binaries are reused from `cpu` to avoid duplicate compilation.
The CPU regression's existing results are not overwritten by the separate app.

To test just the replaced single-cycle core with asynchronous memory:

```sh
CORE_MODES=0 MEMORY_MODES=async COMPARE_BASELINE=0 bash run_app05.sh
```

App generation and an independent Python RV32I software-model check run before
the app05 RTL run. For an explicit combined regression, use
`APPS="all_suit app05_instruction" bash run_milestone1_cpu.sh`.

Per-instruction outcomes use the ordered fail-fast protocol: after SELF_FAIL at
case k, earlier cases passed, case k failed, later cases are NOT_RUN. A mnemonic
with some passing and some unexecuted cases is PARTIAL. On timeout or an invalid
completion protocol, per-case results are UNCONFIRMED rather than assumed PASS.
These are check results, not counts of incidental instructions executed by the
test's own setup/assertion code. Every instruction's full set must pass for its
mnemonic to be reported PASS.

Per configuration: `instructions.txt`, `instructions.tsv`, `instructions.json`.
The app05 root also contains a combined `instructions.tsv`/`instructions.json`
across all requested core and memory configurations. The script returns nonzero
if an instruction fails. The shared pipeline PC update now clears bit 0 only
for JALR targets; app05's final odd-target case guards this behavior.

## Replacements

`01_bench/Milestone1/prepare_cpu.py` derives an alternative file list from
`bench_CPU/filelist` and replaces four original module definitions:

| CPU module | Implementation used |
| --- | --- |
| alu | Milestone1 ALU, with its one adder, comparator and shifter |
| branch_comp | Milestone1 magnitude_comparator calling the package function |
| regfile | Milestone1 register storage and asynchronous reset |
| data_mem | Milestone1 byte-enabled async or sync memory |

Original CPU, LSU, cache and control sources are reused.
Integration does not replace the legacy block files or rewrite the default bench
file list. The shared pipeline in `00_src/rv32i.sv` includes the JALR bit-zero
correction, applying equally to baseline and Milestone1 builds. Standalone lab
tests remain selected by `10_sim/flist` and `run_milestone1.sh`.

Only the `alu` and `regfile` module declarations are renamed in generated copies
to `milestone1_alu` and `milestone1_regfile`, allowing adapters with legacy names.
Their tested datapath bodies are copied verbatim. Generated sources and file
lists live under `02_test/Milestone1/cpu`, separate from the original sources.
The lab package is now `cpu_pkg` in `00_src/Milestone1/cpu_pkg.sv`; the legacy
CPU still uses `rv32i_pkg`. Both are compiled in dependency order.

The original program ROM ignores +PROG. A generated bench-only ROM adds actual
runtime program loading. A generated top and TOP_SYNTH increase instruction-ROM
capacity from 1 KiB to 4 MiB to hold the generated sweep. Both changes apply
identically to baseline and replacement builds. They do not change the CPU
datapath, data-memory latency, or reset/cycle-count protocol. These wrappers
are simulation resources, not FPGA synthesis/board configurations.

## Interface adaptation

- ALU port names are mapped; operation codes 0..9 match both packages.
- Branch comparison maps eq/lt to the original branch interface.
- The single-cycle core sets BYPASS=0. For pipeline cores the adapter adds the
  existing WB-to-ID forwarding outside the lab register file. The lab module
  itself retains no-bypass behavior and its asynchronous reset.
- The unchanged LSU decodes the CPU data range 0x2000..0x3fff and passes a local
  offset. The lab memory uses START_ADDR=0 and the original ADDR_W capacity.
- Both memory adapters preserve the original request detection and nine-stage
  READY delay. A synchronous read is sampled on the request edge and held until
  the CPU/cache receives READY. Byte masks are passed through unchanged.
- MEM_FLOP is required. External SRAM pins are inactive; this is a simulation
  integration test, not an FPGA SRAM test.

## Results and scope

Per configuration, lint/build/results logs and simulation binaries are under
`02_test/Milestone1/cpu/<baseline|async|sync>_mode<N>/`.
`summary.tsv` records each requested configuration's result. Per-app machine-readable
results are in `results.json`; `cycle_comparison.tsv`, `app_results.json`, and
`RESULTS.md` provide the cycle deltas and exact comparison with baseline.

`all_suit` has 14 self-checks across array sum, factorial, Fibonacci, division/GCD,
signed sorting, sieve, matrix multiplication and bit operations. Expected LEDR
is 0x00003fff. Expected LEDG is 0x600d (0x00d on the 9-bit TOP_SYNTH adapter).
The old eight individual algorithm ROMs remain absent and are not selected.
App 05 includes 63,724 checks over all 37 instructions implemented by this core.
See `02_test/Milestone1/apps/README.md` and `app05_manifest.json` for the exact
exhaustive domains and the case-ID map. Full 32-bit operand combinations are
not exhaustive; unsupported FENCE/SYSTEM/CSR/trap behavior is outside this test.

## Exact PASS/FAIL conditions

Every app gets a fresh model and its own ROM. The CPU first writes its signature
or failing case ID to LEDR at 0x7000, then writes status to LEDG at 0x7010.
The runner stops when LEDG becomes nonzero or the cycle budget expires.

| Condition | CORE_MODE 0..2 (32-bit LEDG) | CORE_MODE 3 (9-bit LEDG) |
| --- | --- | --- |
| PASS | LEDG exactly 0x600d AND LEDR equals the app signature | LEDG exactly 0x00d AND LEDR equals the app signature |
| SELF_FAIL | LEDG exactly 0x0bad; LEDR identifies failing check | LEDG exactly 0x1ad; LEDR identifies failing check |
| LEDR_MISMATCH | PASS status with incorrect signature | Same |
| BAD_LEDG | Any other nonzero LEDG, including 0x00d on a 32-bit core | Any other nonzero LEDG |
| TIMEOUT | No completion within the app cycle budget | Same |
| MISSING_ROM | ROM file does not exist | Same |

all_suit signature: LEDR=0x3fff; budget: 1,000,000 cycles.
App 05 signature: LEDR=63,724 (0xf8ec); budget: 20,000,000 cycles.
The last failing case ID is also 63,724. Thus LEDR=0xf8ec alone cannot distinguish
success from failure: LEDG is authoritative, and both fields must match PASS.
Lint/build failures and all non-PASS simulation outcomes cause a nonzero script exit.
Cycle counting uses the same initial reset edge plus two reset-loop cycles as
the old runner. It measures reset-loop cycles through the first nonzero LEDG.

These PASS/FAIL rules are identical for async and sync memory. The distinction
is when the raw read output changes: async follows address combinationally;
sync updates after a rising edge with read enable and holds otherwise. The
sync lab memory uses read-before-write when both enables are high. The CPU
adapter issues either read or write, so simultaneous access is tested by the
standalone memory bench, not by the CPU app.

Both CPU memory adapters retain the old nine-stage READY pipeline. This hides
the synchronous memory's one-cycle raw read latency, so equal total CPU cycles
are expected. It does not mean raw async/sync memory timing is identical.

The runner keeps -Wall and logs warnings, with -Wno-fatal for CPU integration.
It sets --unroll-count 1024 to support the unchanged tournament predictor's
512-entry reset loops on Verilator 5.020, avoiding BLKLOOPINIT tool errors.
The lab register file's asynchronous reset shares a net with legacy synchronous
reset logic (SYNCASYNCNET). START_ADDR=0 can also produce a constant unsigned
lower-bound check warning. These do not change simulation results. All warning
details remain in each configuration's logs; standalone lab lint stays strict.

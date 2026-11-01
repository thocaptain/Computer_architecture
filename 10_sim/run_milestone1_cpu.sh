#!/usr/bin/env bash
# Full CPU regression: original blocks versus Milestone1 blocks.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS="$PROJECT_ROOT/02_test/Milestone1/cpu"
RUN_RESULTS="${RUN_RESULTS:-$RESULTS}"
VERILATOR="${VERILATOR:-verilator}"
CORE_MODES="${CORE_MODES:-0 1 2 3}"
MEMORY_MODES="${MEMORY_MODES:-async sync}"
COMPARE_BASELINE="${COMPARE_BASELINE:-1}"
APPS="${APPS:-all_suit}"
PRINT_INSTRUCTIONS="${PRINT_INSTRUCTIONS:-0}"

for core in $CORE_MODES; do
    case "$core" in 0|1|2|3) ;; *) echo "Invalid CORE_MODES: $core" >&2; exit 2;; esac
done
for memory in $MEMORY_MODES; do
    case "$memory" in async|sync) ;; *) echo "Invalid MEMORY_MODES: $memory" >&2; exit 2;; esac
done
case "$COMPARE_BASELINE" in 0|1) ;; *) echo "COMPARE_BASELINE must be 0 or 1" >&2; exit 2;; esac
for app in $APPS; do
    case "$app" in all_suit|app05_instruction) ;; *) echo "Unknown app: $app" >&2; exit 2;; esac
done
if [[ " $APPS " == *" app05_instruction "* ]]; then
    python3 "$PROJECT_ROOT/01_bench/Milestone1/generate_app05.py"
    python3 "$PROJECT_ROOT/01_bench/Milestone1/check_app05_model.py"
elif [[ ! -f "$PROJECT_ROOT/02_test/Milestone1/apps/app05_config.h" ]]; then
    # The shared C++ runner needs the metadata header even if app05 is not selected.
    python3 "$PROJECT_ROOT/01_bench/Milestone1/generate_app05.py"
fi
python3 "$PROJECT_ROOT/01_bench/Milestone1/prepare_cpu.py"
cd "$PROJECT_ROOT/bench_CPU"
mkdir -p "$RUN_RESULTS"
"$VERILATOR" --version | tee "$RUN_RESULTS/tool_version.log"
printf 'configuration\tcore_mode\tstatus\n' > "$RUN_RESULTS/summary.tsv"

run_case() {
    local configuration="$1" core="$2"
    local case_dir="$RESULTS/${configuration}_mode${core}"
    local run_dir="$RUN_RESULTS/${configuration}_mode${core}"
    local filelist="$RESULTS/filelist"
    local defines=()
    mkdir -p "$case_dir" "$run_dir"
    : > "$run_dir/results.json"
    if [[ "$configuration" == baseline ]]; then
        filelist="$RESULTS/baseline_filelist"
    elif [[ "$configuration" == sync ]]; then
        defines+=(+define+MILESTONE1_SYNC_MEMORY)
    fi
    echo "==> CPU core=$core blocks=$configuration: lint"
    # Legacy RTL warnings remain visible in logs; do not alter old modules for lint.
    local common=(-sv -Wall -Wno-fatal -Wno-EOFNEWLINE -Wno-PINCONNECTEMPTY
                  --unroll-count 1024 --assert -GCORE_MODE="$core" -f "$filelist"
                  "$RESULTS/generated/top.sv" --top-module top)
    if ! "$VERILATOR" --lint-only "${common[@]}" "${defines[@]}" > "$run_dir/lint.log" 2>&1; then
        cat "$run_dir/lint.log"
        printf '%s\t%s\tLINT_FAIL\n' "$configuration" "$core" >> "$RUN_RESULTS/summary.tsv"
        return 1
    fi
    echo "==> CPU core=$core blocks=$configuration: build"
    if ! "$VERILATOR" --cc --trace -O3 -x-initial unique -x-assign unique \
        "${common[@]}" "${defines[@]}" --Mdir "$case_dir/obj_dir" \
        -CFLAGS "-DCPU_CORE_MODE=$core" \
        --exe "$PROJECT_ROOT/01_bench/Milestone1/cpu_runner.cpp" --build -j 2 > "$run_dir/build.log" 2>&1; then
        tail -n 60 "$run_dir/build.log"
        printf '%s\t%s\tBUILD_FAIL\n' "$configuration" "$core" >> "$RUN_RESULTS/summary.tsv"
        return 1
    fi
    echo "==> CPU core=$core blocks=$configuration: $APPS"
    # APPS is a validated space-separated list of names, deliberately split here.
    local exit_status=0
    if "$case_dir/obj_dir/Vtop" $APPS --json "$run_dir/results.json" 2>&1 | tee "$run_dir/results.log" \
        | sed -n '/^\[RUN\]/p; /^APP /p'; then
        printf '%s\t%s\tPASS\n' "$configuration" "$core" >> "$RUN_RESULTS/summary.tsv"
    else
        printf '%s\t%s\tFAIL\n' "$configuration" "$core" >> "$RUN_RESULTS/summary.tsv"
        exit_status=1
    fi
    if [[ "$PRINT_INSTRUCTIONS" == 1 ]]; then
        if ! python3 "$PROJECT_ROOT/01_bench/Milestone1/report_app05.py" "$run_dir/results.json" "$configuration"; then
            return 1
        fi
    fi
    return "$exit_status"
}

failures=0
for core in $CORE_MODES; do
    if [[ "$COMPARE_BASELINE" == 1 ]]; then
        if ! run_case baseline "$core"; then failures=$((failures + 1)); fi
    fi
    for memory in $MEMORY_MODES; do
        if ! run_case "$memory" "$core"; then failures=$((failures + 1)); fi
    done
done
cat "$RUN_RESULTS/summary.tsv"
python3 "$PROJECT_ROOT/01_bench/Milestone1/summarize_cpu.py" "$RUN_RESULTS"
if (( failures != 0 )); then
    echo "CPU integration failed in $failures configuration(s). See $RUN_RESULTS" >&2
    exit 1
fi
echo "MILESTONE1 CPU PASS: all requested configurations passed the requested apps."

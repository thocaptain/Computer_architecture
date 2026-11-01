#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESULTS="$PROJECT_ROOT/02_test/Milestone1"
VERILATOR="${VERILATOR:-verilator}"
cd "$PROJECT_ROOT/10_sim"
mkdir -p "$RESULTS/obj_dir"
"$VERILATOR" --version | tee "$RESULTS/tool_version.log"
"$VERILATOR" --lint-only --sv --timing -Wall -Wno-PINCONNECTEMPTY -f flist \
    2>&1 | tee "$RESULTS/lint.log"
"$VERILATOR" --binary --sv --timing --trace --assert -Wall -Wno-PINCONNECTEMPTY \
    -j 2 --Mdir "$RESULTS/obj_dir" -f flist 2>&1 | tee "$RESULTS/build.log"
"$RESULTS/obj_dir/Vtbench" "$@" 2>&1 | tee "$RESULTS/results.log"

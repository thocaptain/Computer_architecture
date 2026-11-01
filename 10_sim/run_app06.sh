#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 01_bench/Milestone1/app06/prepare_app06.py
OUT="$ROOT/02_test/Milestone1/app06"
mkdir -p "$OUT/sim"
cp "$OUT/app06_sim.mem" "$OUT/sim/app06.mem"
verilator --cc --exe --build -j 4 -Wno-fatal --top-module app06_de2_115 \
  -GDEBOUNCE_CYCLES=4 -f "$OUT/filelist" \
  "$ROOT/01_bench/Milestone1/app06/runner.cpp" \
  --Mdir "$OUT/sim/obj_dir" > "$OUT/sim/build.log" 2>&1
cd "$OUT/sim"
./obj_dir/Vapp06_de2_115 | tee results.log

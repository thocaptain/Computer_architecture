#!/usr/bin/env bash
# App 05 only, with all 37 instruction results printed for each CPU configuration.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export APPS=app05_instruction
export PRINT_INSTRUCTIONS=1
export RUN_RESULTS="$SCRIPT_DIR/../02_test/Milestone1/app05"
exec bash "$SCRIPT_DIR/run_milestone1_cpu.sh"

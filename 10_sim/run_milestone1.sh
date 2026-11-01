#!/usr/bin/env bash
# Run from any directory; forward simulator arguments such as +wave.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/../01_bench/Milestone1/run.sh" "$@"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SIM_CXX="${SIM_CXX:-}"
if [[ -z "$SIM_CXX" ]]; then
  if command -v g++-10 >/dev/null 2>&1; then
    SIM_CXX="g++-10"
  else
    SIM_CXX="g++"
  fi
fi

echo "==> Using C++ compiler: $SIM_CXX"

echo "==> Checking selected testbench"
if ! grep -Eq '^[[:space:]]*\./\.\./01_bench/alu/tbench\.sv[[:space:]]*$' flist; then
  echo "ERROR: 10_sim/flist is not selecting the ALU testbench."
  echo "Enable this line in flist:"
  echo "./../01_bench/alu/tbench.sv"
  exit 1
fi

if grep -Eq '^[[:space:]]*\./\.\./01_bench/TOP/tbench\.sv[[:space:]]*$' flist; then
  echo "ERROR: 10_sim/flist also selects TOP/tbench.sv."
  echo "Only one tbench module should be enabled. Comment TOP/tbench.sv first."
  exit 1
fi

echo "==> Cleaning previous build"
make clean

echo "==> Linting ALU bench"
make lint

echo "==> Building ALU bench"
make sim SIM_CXX="$SIM_CXX"

echo "==> Running ALU bench"
make run

echo "==> ALU test completed"

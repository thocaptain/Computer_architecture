#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
xelatex -interaction=nonstopmode -halt-on-error Milestone1_Report.tex
xelatex -interaction=nonstopmode -halt-on-error Milestone1_Report.tex

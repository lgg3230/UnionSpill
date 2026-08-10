#!/bin/bash
# _run_clause_types.sh
# Usage: bash Programs/clause_types/_run_clause_types.sh

set -e

GIT_ROOT=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT"

mkdir -p Logs/clause_types Tables/clause_types Graphs/clause_types

echo "============================================================"
echo "CLAUSE TYPES PIPELINE"
echo "Started: $(date)"
echo "============================================================"

echo ""
echo "Step 1: Estimate clause-type spillover heterogeneity (Stata)"
if command -v stata-mp >/dev/null 2>&1; then
    stata-mp -b do Programs/clause_types/_run_clause_types.do
elif command -v stata-se >/dev/null 2>&1; then
    stata-se -b do Programs/clause_types/_run_clause_types.do
elif command -v stata >/dev/null 2>&1; then
    stata -b do Programs/clause_types/_run_clause_types.do
else
    echo "No Stata binary found in PATH."
    exit 1
fi

echo ""
echo "Step 2: Build LaTeX table (Python)"
python3 Programs/clause_types/generate_clause_count_latex.py

echo ""
echo "============================================================"
echo "PIPELINE COMPLETE: $(date)"
echo "============================================================"

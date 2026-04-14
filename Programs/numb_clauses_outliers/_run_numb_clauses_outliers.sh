#!/bin/bash
# _run_numb_clauses_outliers.sh
# Usage: bash Programs/numb_clauses_outliers/_run_numb_clauses_outliers.sh

set -e

GIT_ROOT=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT"

mkdir -p Logs/numb_clauses_outliers Tables/numb_clauses_outliers Graphs/numb_clauses_outliers

echo "============================================================"
echo "NUMB CLAUSES OUTLIERS PIPELINE"
echo "Started: $(date)"
echo "============================================================"

echo ""
echo "Step 1: Estimate outlier sensitivity regressions (Stata)"
if command -v stata-mp >/dev/null 2>&1; then
    stata-mp -b do Programs/numb_clauses_outliers/_run_numb_clauses_outliers.do
elif command -v stata-se >/dev/null 2>&1; then
    stata-se -b do Programs/numb_clauses_outliers/_run_numb_clauses_outliers.do
elif command -v stata >/dev/null 2>&1; then
    stata -b do Programs/numb_clauses_outliers/_run_numb_clauses_outliers.do
else
    echo "No Stata binary found in PATH."
    exit 1
fi

echo ""
echo "Step 2: Estimate prefix-excluded labor outcome regressions (Stata)"
if command -v stata-mp >/dev/null 2>&1; then
    stata-mp -b do Programs/numb_clauses_outliers/_run_labor_prefix_effects.do
elif command -v stata-se >/dev/null 2>&1; then
    stata-se -b do Programs/numb_clauses_outliers/_run_labor_prefix_effects.do
elif command -v stata >/dev/null 2>&1; then
    stata -b do Programs/numb_clauses_outliers/_run_labor_prefix_effects.do
else
    echo "No Stata binary found in PATH."
    exit 1
fi

echo ""
echo "Step 3: Estimate top-1%-excluded labor spillover regressions (Stata)"
if command -v stata-mp >/dev/null 2>&1; then
    stata-mp -b do Programs/numb_clauses_outliers/_run_labor_top1_effects.do
elif command -v stata-se >/dev/null 2>&1; then
    stata-se -b do Programs/numb_clauses_outliers/_run_labor_top1_effects.do
elif command -v stata >/dev/null 2>&1; then
    stata -b do Programs/numb_clauses_outliers/_run_labor_top1_effects.do
else
    echo "No Stata binary found in PATH."
    exit 1
fi

echo ""
echo "Step 4: Build outlier LaTeX tables (Python)"
python3 Programs/numb_clauses_outliers/generate_numb_clause_outlier_latex.py

echo ""
echo "Step 5: Build prefix labor-outcome LaTeX tables (Python)"
python3 Programs/numb_clauses_outliers/generate_labor_prefix_latex.py

echo ""
echo "Step 6: Build top-1% labor-outcome LaTeX table (Python)"
python3 Programs/numb_clauses_outliers/generate_labor_top1_latex.py

echo ""
echo "============================================================"
echo "PIPELINE COMPLETE: $(date)"
echo "============================================================"

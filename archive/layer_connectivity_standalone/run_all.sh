#!/usr/bin/env bash
# Full replication wrapper: runs all Stata regressions then generates LaTeX tables.
# Usage:  bash run_all.sh
#         STATA=/usr/local/stata17/stata-mp PYTHON=python3 bash run_all.sh
#
# Exercise 5 (within-firm group exhibits) is invoked as TWO SEPARATE Stata
# processes, and not from run_all.do. This is required, not stylistic: reghdfe
# picks up session state from earlier estimation, which moves the ten2
# group-level coefficients in the 6th significant digit. One process per pass
# reproduces the published numbers exactly.

set -euo pipefail

STATA="${STATA:-stata-mp}"
PYTHON="${PYTHON:-python3}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

cd "$ROOT"

echo "=== Step 1: Stata regressions, exercises 1-4 ==="
"$STATA" -b do "$ROOT/scripts/run_all.do"

echo "=== Step 2: Stata regressions, exercise 5 (own process per pass) ==="
"$STATA" -b do "$ROOT/scripts/05_run_within_firm.do"
"$STATA" -b do "$ROOT/scripts/05_run_within_firm_hw.do"

echo "=== Step 3: LaTeX tables ==="
"$PYTHON" "$ROOT/scripts/01b_make_table_spillover.py"
"$PYTHON" "$ROOT/scripts/02b_make_table_horse_race.py"
"$PYTHON" "$ROOT/scripts/03b_make_table_spillover_occ4.py"
"$PYTHON" "$ROOT/scripts/04b_make_table_horse_race_occ4.py"
"$PYTHON" "$ROOT/scripts/05b_make_tables_within_firm.py"

echo "=== Done. Results in $ROOT/output/ ==="

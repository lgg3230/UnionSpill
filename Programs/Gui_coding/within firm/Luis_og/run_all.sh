#!/usr/bin/env bash
# Full replication wrapper: runs all Stata regressions then generates LaTeX tables.
# Usage:  bash run_all.sh
#         STATA=/usr/local/stata17/stata-mp PYTHON=python3 bash run_all.sh

set -euo pipefail

STATA="${STATA:-stata-mp}"
PYTHON="${PYTHON:-python3}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Step 1: Stata regressions ==="
"$STATA" -b do "$ROOT/scripts/run_all.do"

echo "=== Step 2: LaTeX tables ==="
"$PYTHON" "$ROOT/scripts/01b_make_table_spillover.py"
"$PYTHON" "$ROOT/scripts/02b_make_table_horse_race.py"
"$PYTHON" "$ROOT/scripts/03b_make_table_spillover_occ4.py"
"$PYTHON" "$ROOT/scripts/04b_make_table_horse_race_occ4.py"

echo "=== Done. Results in $ROOT/output/ ==="

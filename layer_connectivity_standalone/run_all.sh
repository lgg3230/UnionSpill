#!/usr/bin/env bash
# Convenience shell wrapper — delegates to scripts/run_all.do.
# Usage:  bash run_all.sh
#         STATA=/usr/local/stata17/stata-mp bash run_all.sh

set -euo pipefail

STATA="${STATA:-stata-mp}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

"$STATA" -b do "$ROOT/scripts/run_all.do"

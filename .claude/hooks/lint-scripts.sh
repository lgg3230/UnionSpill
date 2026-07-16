#!/bin/bash
# lint-scripts.sh — Mechanical grep-based linter for R, Python, Julia scripts.
# Catches prohibited patterns from coding standards before the coder-critic runs.
# Exit code: always 0 (advisory). Output goes to stdout for agent consumption.
#
# Usage:
#   lint-scripts.sh <file>           # Lint a single file
#   lint-scripts.sh <dir>            # Lint all scripts in directory (recursive)
#   lint-scripts.sh                  # Lint scripts/ in current project

set -uo pipefail

# --- Resolve target ---
TARGET="${1:-scripts}"
FILES=()

if [[ -f "$TARGET" ]]; then
  FILES=("$TARGET")
elif [[ -d "$TARGET" ]]; then
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(find "$TARGET" -type f \( -name "*.R" -o -name "*.py" -o -name "*.jl" \) -print0 2>/dev/null)
else
  echo "LINT: Target not found: $TARGET"
  exit 0
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "LINT: No R/Python/Julia scripts found in $TARGET"
  exit 0
fi

TOTAL_ISSUES=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0

# --- Lint one file ---
lint_file() {
  local file="$1"
  local ext="${file##*.}"
  local issues=0
  local findings=""

  add_finding() {
    local severity="$1"
    local line="$2"
    local msg="$3"
    findings+="  [$severity] Line $line: $msg"$'\n'
    issues=$((issues + 1))
    case "$severity" in
      HIGH)   TOTAL_HIGH=$((TOTAL_HIGH + 1)) ;;
      MEDIUM) TOTAL_MEDIUM=$((TOTAL_MEDIUM + 1)) ;;
      LOW)    TOTAL_LOW=$((TOTAL_LOW + 1)) ;;
    esac
  }

  add_finding_noline() {
    local severity="$1"
    local msg="$2"
    findings+="  [$severity] $msg"$'\n'
    issues=$((issues + 1))
    case "$severity" in
      HIGH)   TOTAL_HIGH=$((TOTAL_HIGH + 1)) ;;
      MEDIUM) TOTAL_MEDIUM=$((TOTAL_MEDIUM + 1)) ;;
      LOW)    TOTAL_LOW=$((TOTAL_LOW + 1)) ;;
    esac
  }

  # ===== COMMON CHECKS (all languages) =====

  # Absolute paths
  while IFS=: read -r num line; do
    [[ -n "$num" ]] && add_finding "HIGH" "$num" "Absolute path detected: ${line:0:80}"
  done < <(grep -n '/Users/\|/home/\|/opt/\|C:\\\\' "$file" 2>/dev/null | grep -v '^\s*#\|^\s*//\|^\s*%' || true)

  # ===== R-SPECIFIC CHECKS =====
  if [[ "$ext" == "R" ]]; then

    # setwd()
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "HIGH" "$num" "setwd() — use here() instead"
    done < <(grep -n 'setwd(' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # rm(list = ls())
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "rm(list = ls()) — restart R instead"
    done < <(grep -n 'rm(list\s*=\s*ls()' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # install.packages() in scripts
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "HIGH" "$num" "install.packages() in script — use renv"
    done < <(grep -n 'install\.packages(' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # T/F instead of TRUE/FALSE (= T, or = F, at end of argument)
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "T/F literal — use TRUE/FALSE"
    done < <(grep -nE '=\s*(T|F)\s*[,\)]' "$file" 2>/dev/null | grep -v '^\s*#\|TRUE\|FALSE' || true)

    # sapply()
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "sapply() — use vapply() or lapply()"
    done < <(grep -n 'sapply(' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # attach() / detach()
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "attach()/detach() — use explicit references"
    done < <(grep -n 'attach(\|detach(' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # <<- global assignment
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "<<- global assignment — pass through arguments"
    done < <(grep -n '<<-' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # require() instead of library()
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "LOW" "$num" "require() — use library() instead"
    done < <(grep -n 'require(' "$file" 2>/dev/null | grep -v '^\s*#\|requireNamespace' || true)

    # library() after line 30 (packages should be at top)
    while IFS=: read -r num _; do
      if [[ -n "$num" && "$num" -gt 30 ]]; then
        add_finding "LOW" "$num" "library() call after line 30 — load packages at top"
      fi
    done < <(grep -n '^[^#]*library(' "$file" 2>/dev/null || true)

    # print() for status (not inside function definitions or strings)
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "LOW" "$num" "print() — use message() for status output"
    done < <(grep -n '^[^#]*\bprint(' "$file" 2>/dev/null | grep -v 'printCoefmat\|print\.data' || true)

    # 1:length(), 1:nrow(), 1:ncol(), 1:n (common unsafe patterns)
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "LOW" "$num" "1:n pattern — use seq_len() or seq_along()"
    done < <(grep -nE '1:(length|nrow|ncol|NROW|NCOL)\(' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # set.seed() check — warn if stochastic keywords present but no set.seed
    if grep -q 'sample(\|rnorm(\|runif(\|rbinom(\|bootstrap\|boot\|replicate(' "$file" 2>/dev/null; then
      if ! grep -q 'set\.seed(' "$file" 2>/dev/null; then
        add_finding_noline "HIGH" "Stochastic code detected but no set.seed() — add set.seed() at top"
      fi
    fi

    # set.seed() position — should be near top (first 30 lines)
    local seed_line
    seed_line=$(grep -n 'set\.seed(' "$file" 2>/dev/null | head -1 | cut -d: -f1)
    if [[ -n "$seed_line" && "$seed_line" -gt 30 ]]; then
      add_finding "MEDIUM" "$seed_line" "set.seed() should be near top of script (within first 30 lines)"
    fi

    # Prohibited packages
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "stargazer is deprecated — use modelsummary or fixest::etable"
    done < <(grep -n 'library(stargazer)\|require(stargazer)' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "plyr is superseded — use data.table"
    done < <(grep -n 'library(plyr)\|require(plyr)' "$file" 2>/dev/null | grep -v '^\s*#' || true)

  fi

  # ===== PYTHON-SPECIFIC CHECKS =====
  if [[ "$ext" == "py" ]]; then

    # os.chdir()
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "HIGH" "$num" "os.chdir() — use pathlib.Path instead"
    done < <(grep -n 'os\.chdir(' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # from X import *
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "Wildcard import — use explicit imports"
    done < <(grep -n 'from .* import \*' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # np.random.seed() global state
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "np.random.seed() global state — use np.random.default_rng(seed)"
    done < <(grep -n 'np\.random\.seed(' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # bare except:
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "Bare except: — catch specific exceptions"
    done < <(grep -nE '^[[:space:]]*except[[:space:]]*:' "$file" 2>/dev/null || true)

    # import after line 30
    while IFS=: read -r num _; do
      if [[ -n "$num" && "$num" -gt 30 ]]; then
        add_finding "LOW" "$num" "Import after line 30 — put imports at top"
      fi
    done < <(grep -nE '^[[:space:]]*(import |from [^ ]+ import )' "$file" 2>/dev/null || true)

    # pip install in scripts
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "HIGH" "$num" "pip install in script — use requirements.txt"
    done < <(grep -n 'pip install\|subprocess.*pip' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # Seed check — stochastic code without seed
    if grep -q 'np\.random\.\|random\.\|torch\.rand' "$file" 2>/dev/null; then
      if ! grep -q 'default_rng\|random\.seed\|manual_seed\|SEED' "$file" 2>/dev/null; then
        add_finding_noline "HIGH" "Stochastic code detected but no seed set — use np.random.default_rng(SEED)"
      fi
    fi

  fi

  # ===== JULIA-SPECIFIC CHECKS =====
  if [[ "$ext" == "jl" ]]; then

    # cd()
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "HIGH" "$num" "cd() — use joinpath(@__DIR__, ...) instead"
    done < <(grep -nE '^[[:space:]]*cd\(' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # eval / @eval at runtime
    while IFS=: read -r num line; do
      [[ -n "$num" ]] && add_finding "MEDIUM" "$num" "eval/@eval at runtime — use multiple dispatch"
    done < <(grep -n '@eval\|eval(' "$file" 2>/dev/null | grep -v '^\s*#' || true)

    # Seed check
    if grep -q 'rand(\|randn(\|shuffle' "$file" 2>/dev/null; then
      if ! grep -q 'MersenneTwister\|Random\.seed!\|SEED' "$file" 2>/dev/null; then
        add_finding_noline "HIGH" "Stochastic code detected but no RNG seed — use MersenneTwister(SEED)"
      fi
    fi

    # using after line 30
    while IFS=: read -r num _; do
      if [[ -n "$num" && "$num" -gt 30 ]]; then
        add_finding "LOW" "$num" "using/import after line 30 — put at top"
      fi
    done < <(grep -nE '^[[:space:]]*(using |import )' "$file" 2>/dev/null || true)

  fi

  # ===== OUTPUT =====
  TOTAL_ISSUES=$((TOTAL_ISSUES + issues))
  if [[ $issues -gt 0 ]]; then
    echo "$file ($issues issues):"
    echo -n "$findings"
  fi
}

# --- Main ---
echo "=== LINT REPORT ==="
echo ""

for f in "${FILES[@]}"; do
  lint_file "$f"
done

echo ""
echo "--- Summary ---"
echo "Files scanned: ${#FILES[@]}"
echo "Total issues:  $TOTAL_ISSUES (HIGH: $TOTAL_HIGH, MEDIUM: $TOTAL_MEDIUM, LOW: $TOTAL_LOW)"

if [[ $TOTAL_ISSUES -eq 0 ]]; then
  echo "Status: CLEAN"
else
  echo "Status: $TOTAL_ISSUES issue(s) found — review before committing"
fi

exit 0

#!/usr/bin/env bash
# paper_push.sh — safe commit + merge + verify + push for the UnionSpill_paper repo.
#
# Automates the fetch/merge/push dance so a co-author editing Overleaf directly
# and this side (git) stop diverging:
#   1. stage + commit the named files (or everything with -A)
#   2. fetch + merge origin/main (co-author's latest Overleaf edits)
#        - conflicts in GENERATED fragments  -> auto-resolve to OUR version
#        - conflicts in hand-edited files    -> abort for manual resolution
#   3. smoke-test each generated table fragment with tectonic (minimal preamble)
#   4. warn about any \includegraphics whose file is missing
#   5. push only if everything passed
#
# Usage:
#   paper_push.sh "commit message" [file ...]      # commit named files (recommended)
#   paper_push.sh "commit message" -A              # commit everything staged/modified
#   paper_push.sh --sync                           # no commit; just merge + push (sync)
set -euo pipefail

PAPER="/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/UnionSpill_paper"
# generated fragments the co-author never hand-edits (auto-resolve to ours on conflict)
GENERATED=("Tables/balance_table_task2.tex")

cd "$PAPER"

MODE_SYNC=0
if [ "${1:-}" = "--sync" ]; then MODE_SYNC=1; shift; fi

# ---- 1. stage + commit -------------------------------------------------------
if [ "$MODE_SYNC" -eq 0 ]; then
    MSG="${1:?commit message required (or use --sync)}"; shift
    if [ "${1:-}" = "-A" ]; then git add -A; else git add -- "$@"; fi
    if git diff --cached --quiet; then
        echo "· nothing staged to commit — proceeding to sync"
    else
        git commit -q -m "$MSG" \
                    -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
        echo "· committed: $(git log --oneline -1)"
    fi
fi

# ---- 2. fetch + merge --------------------------------------------------------
git fetch -q origin
if ! GIT_EDITOR=true git merge --no-edit origin/main >/dev/null 2>&1; then
    for f in $(git diff --name-only --diff-filter=U); do
        if printf '%s\n' "${GENERATED[@]}" | grep -qxF "$f"; then
            git checkout --ours -- "$f"; git add -- "$f"
            echo "· auto-resolved generated fragment to ours: $f"
        else
            echo "✗ CONFLICT in hand-edited file: $f"
            echo "  Resolve it manually, 'git commit', then rerun with --sync."
            exit 1
        fi
    done
    GIT_EDITOR=true git commit --no-edit -q
    echo "· merged origin/main (generated fragments auto-resolved)"
else
    echo "· merged origin/main (clean)"
fi

# ---- 3. smoke-test generated table fragments (tectonic, minimal preamble) -----
if command -v tectonic >/dev/null 2>&1; then
    for f in "${GENERATED[@]}"; do
        [ -f "$f" ] || continue
        tmp=$(mktemp -d)
        cat > "$tmp/s.tex" <<EOF
\documentclass[12pt]{article}
\usepackage[margin=0.8in,landscape]{geometry}
\usepackage{graphicx,booktabs,threeparttable,amsmath,subcaption,float}
\begin{document}\input{$PAPER/$f}\end{document}
EOF
        if tectonic -X compile "$tmp/s.tex" --outdir "$tmp" >/dev/null 2>&1; then
            echo "· smoke-test OK: $f"
        else
            echo "✗ SMOKE-TEST FAILED: $f does not compile — push aborted."
            rm -rf "$tmp"; exit 1
        fi
        rm -rf "$tmp"
    done
else
    echo "· (tectonic not found — skipping fragment smoke-test)"
fi

# ---- 4. warn on missing figure files (skip commented-out lines) --------------
while IFS= read -r img; do
    [ -f "$img" ] || echo "⚠ referenced figure missing: $img"
done < <(grep -rhE '\\includegraphics' *.tex | grep -vE '^[[:space:]]*%' \
         | grep -oE '\{[^}]*\.(pdf|png|jpg|jpeg|eps)\}' | tr -d '{}' | sort -u)

# ---- 5. push -----------------------------------------------------------------
git push origin main
echo "✓ pushed: $(git log --oneline -1)"

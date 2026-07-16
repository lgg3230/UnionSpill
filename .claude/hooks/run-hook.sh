#!/bin/bash
# run-hook.sh — resolve a Python >= 3.10 and exec the named hook with it.
#
# The compact hooks use `dict | None` syntax (PEP 604), which needs 3.10+.
# The cluster's /usr/bin/python3 is 3.6, so a bare `python3` fails there.
# Hardcoding the conda path would break on other machines, so probe instead.
#
# Usage: run-hook.sh <hook-file.py>

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HOOK_DIR/$1"

[[ -f "$HOOK" ]] || exit 0  # Hook missing: pass through rather than break the tool call

for PY in \
  "$HOME/.conda/envs/venv_python312/bin/python3" \
  /home/lgg3230/.conda/envs/venv_python312/bin/python3 \
  "$(command -v python3.13 2>/dev/null)" \
  "$(command -v python3.12 2>/dev/null)" \
  "$(command -v python3.11 2>/dev/null)" \
  "$(command -v python3.10 2>/dev/null)" \
  "$(command -v python3 2>/dev/null)"
do
  [[ -x "$PY" ]] || continue
  # Require >= 3.10
  "$PY" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null || continue
  exec "$PY" "$HOOK"
done

# No suitable interpreter: pass through silently rather than block every edit.
exit 0

#!/bin/bash
# post-edit-lint.sh — PostToolUse hook that auto-lints R/Python/Julia files
# after Edit or Write operations. Advisory only (exit 0).
#
# Environment variables set by Claude Code:
#   CLAUDE_TOOL_ARG_FILE_PATH — the file that was edited/written

FILE="${CLAUDE_TOOL_ARG_FILE_PATH:-}"
[[ -z "$FILE" ]] && exit 0

# Only run on R/Python/Julia scripts
case "$FILE" in
  *.R|*.py|*.jl) ;;
  *) exit 0 ;;
esac

# Skip files inside .claude/ (hooks, agents, etc.)
case "$FILE" in
  */.claude/*) exit 0 ;;
esac

# Run the linter on the single file
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/lint-scripts.sh" "$FILE" 2>/dev/null

exit 0

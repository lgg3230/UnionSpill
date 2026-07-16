#!/usr/bin/env python3
"""
Protect Files Hook -- PreToolUse

Blocks Edit/Write on protected files. Ported from protect-files.sh, which
depended on `jq` (not installed on the Kellogg cluster). Pure stdlib.

Hook Event: PreToolUse (matcher: Edit|Write)
"""

import fnmatch
import json
import os
import sys

# Add patterns for files to protect. Matched against the basename.
#
# Upstream clo-author also protects "settings.json". Dropped by user decision on
# 2026-07-16: it blocks /update-config and any permission or hook change, and
# settings edits are deliberate rather than accidental. Re-add to restore.
PROTECTED_PATTERNS = [
    "strategy-memo-*.md",
    "referee-report-*.md",
    "quality-score-*.json",
]


def main() -> int:
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, IOError):
        return 0  # Pass through on parse error

    if hook_input.get("tool_name", "") not in ("Edit", "Write"):
        return 0

    file_path = hook_input.get("tool_input", {}).get("file_path", "")
    if not file_path:
        return 0

    basename = os.path.basename(file_path)
    for pattern in PROTECTED_PATTERNS:
        if fnmatch.fnmatch(basename, pattern):
            print(json.dumps({
                "decision": "block",
                "reason": (
                    f"Protected file: {basename}. Edit manually, or remove the "
                    f"pattern from .claude/hooks/protect-files.py"
                ),
            }))
            return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())

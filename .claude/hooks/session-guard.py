#!/usr/bin/env python3
"""
Session Guard Hook -- PreToolUse

Enforces session-scoped guards:
- freeze: blocks Edit/Write outside allowed directories
- careful: blocks destructive Bash commands

Reads guard configuration from .claude/state/session-guards.json.
If no guards are active or the file doesn't exist, passes through immediately.

Hook Event: PreToolUse
"""

import json
import os
import re
import sys
from pathlib import Path


def load_guards() -> dict:
    """Load active guards from session state."""
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_dir:
        return {}

    guards_file = Path(project_dir) / ".claude" / "state" / "session-guards.json"
    if not guards_file.exists():
        return {}

    try:
        return json.loads(guards_file.read_text())
    except (json.JSONDecodeError, IOError):
        return {}


def check_freeze(tool_name: str, tool_input: dict, guards: dict) -> tuple:
    """Check if the edit/write is allowed by freeze guard."""
    freeze = guards.get("freeze", {})
    if not freeze.get("active", False):
        return True, ""

    if tool_name not in ("Edit", "Write"):
        return True, ""

    file_path = tool_input.get("file_path", "")
    if not file_path:
        return True, ""

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")

    # .claude/ is always editable
    if "/.claude/" in file_path or file_path.endswith("/.claude"):
        return True, ""

    # Check against allowed paths
    allowed = freeze.get("allowed_paths", [])
    for allowed_path in allowed:
        # Resolve relative to project dir
        full_allowed = os.path.join(project_dir, allowed_path)
        if file_path.startswith(full_allowed):
            return True, ""

    return False, (
        f"FREEZE ACTIVE: Edit blocked. File '{os.path.basename(file_path)}' "
        f"is outside allowed paths: {allowed}. Run /freeze off to deactivate."
    )


DESTRUCTIVE_PATTERNS = [
    (r"\brm\s+-(r|f|rf|fr)", "rm with recursive/force flags"),
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard"),
    (r"\bgit\s+push\s+--force\b", "git push --force"),
    (r"\bgit\s+push\s+-f\b", "git push -f"),
    (r"\bgit\s+clean\s+-f\b", "git clean -f"),
    (r"\bgit\s+checkout\s+--\s+\.", "git checkout -- ."),
    (r"\bgit\s+branch\s+-D\b", "git branch -D"),
    (r"\bDROP\s+TABLE\b", "DROP TABLE"),
    (r"\bDROP\s+DATABASE\b", "DROP DATABASE"),
    (r"\bchmod\s+777\b", "chmod 777"),
]


def check_careful(tool_name: str, tool_input: dict, guards: dict) -> tuple:
    """Check if the bash command is allowed by careful guard."""
    careful = guards.get("careful", {})
    if not careful.get("active", False):
        return True, ""

    if tool_name != "Bash":
        return True, ""

    command = tool_input.get("command", "")
    if not command:
        return True, ""

    for pattern, description in DESTRUCTIVE_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return False, (
                f"CAREFUL MODE: Blocked '{description}'. "
                f"Run /careful off to deactivate, or rephrase the command."
            )

    return True, ""


def main() -> int:
    """Main hook entry point."""
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, IOError):
        return 0  # Pass through on parse error

    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})

    guards = load_guards()
    if not guards:
        return 0  # No guards active, pass through

    # Check freeze
    allowed, message = check_freeze(tool_name, tool_input, guards)
    if not allowed:
        print(json.dumps({"decision": "block", "reason": message}))
        return 0

    # Check careful
    allowed, message = check_careful(tool_name, tool_input, guards)
    if not allowed:
        print(json.dumps({"decision": "block", "reason": message}))
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())

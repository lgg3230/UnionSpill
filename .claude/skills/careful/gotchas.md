# Careful Skill -- Gotchas

- Pattern matching is substring-based. `git push --force-with-lease` is also blocked (contains `--force`). This is intentional -- `--force-with-lease` is safer but still destructive.
- `rm file.txt` (single file, no `-rf`) is allowed. Only recursive/force patterns are blocked.
- The guard doesn't prevent the user from running commands in their own terminal -- it only blocks Claude's Bash tool calls.
- Careful mode is independent of freeze mode -- you can activate both simultaneously.

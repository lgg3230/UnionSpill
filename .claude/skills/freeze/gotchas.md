# Freeze Skill -- Gotchas

- Freeze paths are relative to project root. `/freeze UnionSpill-paper/` means `$PROJECT_ROOT/paper/`.
- `.claude/` is always editable regardless of freeze -- you can't lock yourself out of configuration.
- Freeze doesn't affect Read or Bash -- you can always read and run commands, just not edit files outside allowed paths.
- Multiple paths: `/freeze UnionSpill-paper/ Programs/` allows both directories.
- Session-scoped means it survives `/compact` but not conversation end.

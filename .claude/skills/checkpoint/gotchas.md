# Checkpoint Skill -- Gotchas

- Obsidian MCP must be connected for vault updates. If offline, checkpoint saves memory + SESSION_REPORT only.
- Convert relative dates to absolute dates in memory entries ("Thursday" --> "2026-05-09").
- Don't save code patterns or architecture to memory -- those are derivable from reading the code.
- Check existing memory files before creating new ones to avoid duplicates.
- SESSION_REPORT.md is append-only. Never overwrite existing entries.
- The research journal only gets an entry if agent work happened this session. Don't log empty sessions.
- Pipeline state JSON and research journal are complementary, not redundant. JSON is for the orchestrator; journal is for humans.

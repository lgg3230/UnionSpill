# Logging

## Session Report
Append to `SESSION_REPORT.md` at end of session or before context compression.
**Rules:** Append only. Bullet points. Include file paths and commit hashes when available.
Create the file if it doesn't exist: `# Session Report — [Project Name]`

**Entry format:**
```markdown
## YYYY-MM-DD HH:MM — [Brief Title]

**Operations:**
- [Scripts run, files created/modified/deleted]

**Decisions:**
- [Choice made] — [rationale]

**Results:**
- [Key findings, outputs produced]

**Commits:**
- `[hash]` [commit message]

**Status:**
- Done: [what's complete]
- Pending: [what remains]
```

## Research Journal
Append to `quality_reports/research_journal.md` whenever an agent completes work — writing code, drafting a section, producing a review, making an editorial decision, or transitioning between phases.
**Rules:** Append only. One entry per agent invocation. Include phase transitions and editorial decisions.

**Entry format:**
```markdown
### YYYY-MM-DD HH:MM — [Agent Name]
**Phase:** [Discovery/Strategy/Execution/Peer Review/Presentation]
**Target:** [file or topic]
**Score:** [XX/100 or PASS/FAIL or N/A]
**Verdict:** [one line — key finding or decision]
**Report:** [path to full report]
```
**Why it exists:** Agents read this to understand pipeline state — the editor checks what strategist-critic scored, the orchestrator checks which phases passed, the coder-critic checks what the coder built. It's the shared context across agents.

Agent outputs (reports, scripts, memos, decisions) are saved to `quality_reports/` by the skills that produce them.

## Pipeline State

Structured pipeline state lives in `quality_reports/pipeline_state.json`.

**Location:** `quality_reports/pipeline_state.json`
**Template:** `templates/pipeline-state.json`
**Format:** JSON (machine-readable)

**Triggers:**
- Created when the first agent in a pipeline completes
- Updated after every agent completion, critic score, or phase transition
- Read as the first action in session recovery

**Relationship to research journal:**
- The research journal is narrative context for humans: "what happened and why"
- The pipeline state is structured context for the orchestrator: "where are we and what's next"
- They are complementary, not redundant

**Execution traces:**
After pipeline completion, the orchestrator generates an execution trace from the pipeline state and saves to `quality_reports/traces/`.

### Trace Analysis

After pipeline completion, read the execution trace and the last 5 traces (if available in `quality_reports/traces/`) to identify recurring patterns.

Analysis covers:
- Agents with first-pass >= 90 (HIGH-PERF)
- Agents that hit 3 strikes (FRICTION)
- Escalations to user (USER ESCALATION)
- Agents whose scores improved most between rounds (learning curve)

Save analysis to: `quality_reports/traces/analysis_{date}.md`

The orchestrator uses this analysis for the Learning Loop (see `orchestrator.md` Section 9).

---

## 4. Project Dashboard

**Managed by the `/dashboard` skill.** See `.claude/skills/dashboard/SKILL.md` for the full specification.

The dashboard is `project_dashboard.html` — a single unified HTML page with all project information. Generated and refreshed by `/dashboard refresh`. Changelog entries appended by `/dashboard add-changelog`.

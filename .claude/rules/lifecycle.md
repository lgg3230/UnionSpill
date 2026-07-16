# Lifecycle: Handoff Validation Protocol

Validation rules for agent dispatch and completion. The Orchestrator runs these checks before and after every agent invocation.

---

## PRE-Dispatch Validation

Before dispatching any agent, the Orchestrator reads the agent's entry in `permissions.md` and verifies:

1. **REQUIRES artifacts exist:**
   - For file paths: `Glob` the path, confirm at least one match
   - For score gates (e.g., "strategist-critic score >= 80"): read the research journal for the most recent critic score
   - For directories: confirm the directory is non-empty

2. **REQUIRES sections present** (when specified):
   - Read the artifact file
   - Check that each required section heading exists
   - Example: strategy memo must contain Estimand, Specification, Assumptions, Robustness Plan, Threats

3. **If PRE validation fails:**
   - Do NOT dispatch the agent
   - Report: "Cannot dispatch [agent]: missing [specific artifact or section]"
   - Suggest: "Run [skill] first to produce [artifact]"

---

## POST-Completion Validation

After an agent completes, before advancing the pipeline:

1. **PRODUCES artifacts exist:**
   - For file paths: verify the file was created or updated
   - For directories: verify at least one file was created

2. **PRODUCES required sections present** (when specified):
   - Read the output artifact
   - Verify each required section heading exists
   - Missing sections: flag as incomplete, do not advance

3. **Critic score recorded:**
   - Verify the paired critic has produced a scored report
   - Verify the score is logged in the research journal

4. **If POST validation fails:**
   - Do NOT advance to the next phase
   - Report: "Agent [name] completed but output is incomplete: [specifics]"
   - Re-dispatch the agent with the specific gaps noted

---

## FAIL-FAST Principle

When validation fails:
- Report immediately with a clear, actionable message
- Never dispatch an agent with missing inputs and hope it works
- Never advance past an agent with missing outputs
- The Orchestrator includes the validation failure in its report to the user

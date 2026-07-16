# Revise Skill -- Gotchas

- DISAGREE items are always flagged for user review -- Claude never autonomously pushes back on referees.
- A single referee report may trigger multiple agent pairs (some comments need new analysis, others just text edits).
- Response letter must map each comment to a specific change. Vague responses ("we revised the text") get rejected.
- Always re-run the full quality check after revisions -- a fix for one comment can break something else.
- Keep the original submission as a tagged commit so you can diff against it.
- NEW ANALYSIS items require user approval before dispatching the coder -- don't start coding without confirmation.
- The response letter is the user's voice. Match their tone, not yours.

# New-Project Skill -- Gotchas

- `/new-project` is the only skill that's always orchestrated -- it launches the full pipeline.
- The pipeline can be entered at any phase if prerequisites exist. Don't force Discovery on a project that already has data + literature.
- Quality gates between phases are blocking. A strategist-critic score of 79 stops the pipeline.
- The orchestrator reads permissions.md for dispatch -- if a new agent was added there but not as a file, dispatch fails.
- The theorist phase is conditional -- only for econometric methods, theory+empirics, structural, or methodological reduced-form papers. Applied papers using off-the-shelf estimators skip it.
- User interaction points are mandatory pauses, not optional. Don't skip the approval step after the strategy memo.
- If interrupted, the pipeline resumes from the last completed phase -- check pipeline_state.json for current state.

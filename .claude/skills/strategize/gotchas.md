# Strategize Skill -- Gotchas

Known failure points and edge cases for identification strategy design.

## Design Selection

- Strategist defaults to DiD when event timing is mentioned. Explicitly state the design if you want IV/RDD/other.
- "Staggered adoption" does not automatically mean DiD is the right choice. If treatment is endogenous, DiD won't save you.
- For staggered DiD: Callaway and Sant'Anna (2021) or Sun and Abraham (2021) are required references. TWFE is flagged as a potential problem by the strategist-critic.
- Selection-on-observables is the weakest design. The strategist should always explain why it's credible in this specific setting, not just invoke Oster bounds.

## Strategy Memo

- Strategy memo requires ALL five sections (Estimand, Specification, Assumptions, Robustness Plan, Threats) -- missing any one fails the strategist-critic review.
- Robustness plan ordering matters: most threatening to least threatening. The strategist-critic checks this.
- The pseudo-code in the memo must be precise enough for the coder to implement without ambiguity. "Run a regression" is not pseudo-code.
- Structural estimation strategies need explicit identification arguments -- "estimate by MLE" is not identification.

## Pre-Analysis Plans

- Pre-analysis plans lock in specifications -- run `/strategize pap` AFTER the strategy memo is approved, not before.
- Every ASSUMED item in a PAP must be flagged with `[ASSUMED]`. A registered PAP with unchecked assumptions is worse than no PAP.
- Power calculations require stated assumptions. Always show sensitivity (how MDE changes with N, attrition, ICC).
- Subgroup analyses must be theory-driven. "We'll look at all subgroups" is exactly what pre-registration prevents.

## Theory Mode

- Theory mode (`/strategize theory`) dispatches the theorist agent, not the strategist. Different workflow, different output.
- The theorist assumes the identification strategy is given. If the strategy is wrong, the theory will be valid but irrelevant.
- Notation must match the paper's existing conventions. The theorist-critic checks INV-7 (notation consistency).
- "Standard regularity conditions" is never acceptable. State every assumption.

## Common Referee Objections

- "Why not just do [other design]?" -- the decision record should address this.
- "Your instrument is invalid because [channel]" -- exclusion restriction arguments must be institutional, not just statistical.
- "Parallel trends could fail because [reason]" -- the robustness plan should include a pre-committed response.
- "Your structural model is too simple" -- justify scope explicitly, don't just defend the model.

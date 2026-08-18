# Randomization inference — dataset construction and engine

Restored from `archive/` on 2026-08-16. `Programs/analysis/rand_inference/` held only
the exhibits (`4130_figure_binscatter.py`, `4151`/`4152_recentered_eventstudy.do`)
while the engine that produces what they plot lived outside the chain.

Run in numeric order (2090 -> 2106). `2090`-`2091` build the inputs, `2092`
validates against the headline estimate, `2093` is the permutation engine, and
`2094`-`2106` are diagnostics and reporting (including the direct-counterfactual
placebo, `2104`-`2106`).

The design permutes the *identity* of the treated set and re-estimates the
spillover; connectivity is exactly linear in the destination set. The reshuffle is
inside-sample CEM, cardinality 13,202.

# CBA Value Pipeline — Design Choices and Reasoning

## Starting point: what does "CBA value" mean?

The session began from a finding that spillover firms' CBAs become more *similar* in content to treated firms, but without more clauses. The question: is the similarity result picking up something real about CBA quality, or just noise?

## Step 1: Moving from year to cba_period

The first substantive decision was switching from calendar year to `cba_period` as the time unit for CBA content outcomes. The motivation was that clause counts only change when a CBA is renegotiated — not annually — so forcing them onto a year-level panel introduces spurious pre-trends from uneven renewal timing. The year-based run confirmed this: `numb_clauses` failed parallel trends at the year level but passed cleanly at the cba_period level.

## Step 2: Choosing subgroup-level weights over clause-type weights

Lagos estimates wage-equivalent values at two levels of aggregation: 24 subgroups and 137 clause types. The clause-type estimates are unreasonably large (–36 to +83 log pts), which Lagos himself flags. We adopted subgroup weights for two reasons: (a) they match Lagos's own preferred specification in Table 7, and (b) the 14 non-selected subgroups receive zero weight not by an explicit assignment but because their coefficients are insignificant — Lagos simply omits them from the scoring formula.

## Step 3: Sign flip and its interpretation

Switching from individual-clause weights to subgroup weights flipped the sign of the direct effect on `cba_value` from negative (–0.012) to positive (+0.007). The negative sign under individual-clause weights was puzzling — it implied treated firms negotiated less valuable CBAs despite more clauses. The positive sign is economically coherent: Súmula 277 increased both clause counts and their wage-equivalent value at treated firms.

## Step 4: The pre-trend problem on cba_value

The pre-trend test on `cba_value` came back significantly negative across all panels. Rather than treating this as a failure of parallel trends, we noted that Lagos himself does not run a pre-trend test for amenity value in Table 7 — he uses a simple 2×2 DiD with no pre-trend diagnostics. This is consistent with the measure being constructed from the reform period itself (Lagos's PageRank and AKM estimates span 2007–2011 and 2012–2016), so it encodes information from both sides of the threshold by construction. The pre-trend test is ill-suited to a measure built this way.

## Step 5: Quantitative comparison with Lagos

Our direct effect (+0.007, ~5% of mean) is about half Lagos's (+0.013, ~10% of mean). Three candidate explanations: (a) we use firm-level CBA coverage while Lagos uses sectoral coverage — sectoral CBAs are longer and the reform likely moved their content more; (b) the Lagos weights are estimated on his sample, which may not transfer perfectly to ours; (c) our more saturated fixed-effect specification absorbs more variation. The sign and significance are fully consistent.

## Step 6: Null spillover and what it implies

No spillover effect on `cba_value` (–0.0009, SE = 0.0016). This is informative in two ways: it reinforces that spillovers in the labor market outcomes are not union-mediated (unions at connected untreated firms did not negotiate better contracts), and it raises questions about the robustness of the CBA similarity finding — if connected firms aren't negotiating more valuable contracts, the observed similarity may reflect shared industry trends rather than genuine reform-driven convergence.

## Step 7: The subgroup sanity check (in progress)

The three-exercise subgroup analysis (in `Programs/clause_types/subgroup_analysis.do`) is designed to decompose the aggregate effects: (a) does subgroup-level similarity also show a spillover? (b) which specific subgroups drive the direct effect on clause counts? (c) is there any composition shift — are treated firms reallocating toward higher-value subgroups even without more total clauses? This last question is the cleanest way to reconcile the positive `cba_value` effect with the null clause-count spillover: if treated firms are substituting toward higher-value subgroups, their CBA value rises without clause count rising proportionally.

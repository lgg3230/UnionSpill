# Section Templates — Paper Drafting by Section and Paper Type

Structure guidance for each major section of an economics paper, adapted by paper type (reduced-form, structural, theory+empirics, descriptive/measurement).

---

## Paper Types

Identify the type from the strategy memo before drafting. Most papers are **reduced-form**, but the writer must recognize the others and shift structure accordingly.

| Type | Signature | Strategy section becomes |
|------|-----------|------------------------|
| **Reduced-form** | DiD, IV, RDD, event study | Empirical Strategy |
| **Structural** | Model estimation, counterfactual simulations | Model + Estimation |
| **Theory + empirics** | Propositions tested with data | Model + Empirical Tests |
| **Descriptive / measurement** | New data, new measure, stylized facts | Measurement / Data Construction |

---

## Introduction (1000--1500 words)

**Common backbone (all paper types):**
1. **Motivation** -- Opening fact or puzzle (1--2 sentences)
2. **Research question** -- One clear sentence
3. **Why it matters** -- Policy or theory stake (1--2 sentences)

**Then diverge by type:**

**Reduced-form:**
4. **Identification preview** -- We use [design] + [data] to estimate [parameter] (2--3 sentences)
5. **Result statement** -- Main result with magnitude and units (1--2 sentences)
6. **Literature positioning** -- Contribution paragraph naming 2--3 specific papers

**Structural:**
4. **Model preview** -- We build a model of [agents doing X] that features [key mechanism] (2--3 sentences)
5. **Estimation and counterfactual preview** -- We estimate the model using [data/moments] and simulate [counterfactual] (1--2 sentences)
6. **Key counterfactual result** -- The counterfactual shows [finding with magnitude] (1--2 sentences)
7. **Literature positioning** -- Contribution on both the modeling and empirical side

**Theory + empirics:**
4. **Theory preview** -- The model predicts [testable implication] because [mechanism] (2--3 sentences)
5. **Empirical preview** -- We test this using [design/data] and find [result] (1--2 sentences)
6. **Literature positioning** -- Contribution to both theory and empirical literatures

**Descriptive / measurement:**
4. **Data or measurement innovation** -- We construct [new measure/dataset] using [method] (2--3 sentences)
5. **Key fact** -- The main finding is [fact with magnitude] (1--2 sentences)
6. **Why it matters** -- This fact implies [revision to existing understanding] (1--2 sentences)
7. **Literature positioning** -- What this changes about the empirical landscape

**All types end with:**
- **Roadmap** -- Optional, one sentence maximum

The contribution statement must appear in the first 2 pages.

---

## Data (800--1200 words)

**Common backbone:**
1. **Source and scope** -- Where the data comes from, sample period, sample size
2. **Variable definitions** -- Table reference for summary statistics
3. **Sample restrictions** -- Each restriction justified with one sentence
4. **Data quality** -- Missingness, measurement concerns, how addressed

**Type-specific additions:**

**Reduced-form:** Define treatment, outcome, and controls. Explain treatment variation (timing, geography, eligibility). Show pre-treatment balance if relevant.

**Structural:** Describe the data moments that will identify the model parameters. Connect observable variation to model primitives. "We observe [X], which pins down [parameter] because [logic]."

**Descriptive / measurement:** The data section IS the core contribution. Describe construction in detail -- sources, linking, cleaning decisions, validation against external benchmarks. This section is longer (1200--1800 words).

---

## Empirical Strategy / Model (800--1500 words)

Start from the strategy memo. The section name and structure depend on the paper type.

### Reduced-form: Empirical Strategy

**Common sequence (all designs):**
1. **Identification preview** -- Design and key assumption in plain language, before any equations
2. **Estimand** -- State what you're estimating (ATT, ATE, LATE) and why it's the right target
3. **Formal specification** -- Numbered equation with notation from the notation protocol
4. **Key assumption** -- Name it, state it formally, explain what it means in plain language
5. **Assumption validation** -- How you test or support the assumption (pre-trends, balance, placebo, falsification)
6. **Threats** -- What could go wrong, and your response to each

**Design-specific moves:**

**Difference-in-Differences:**
- State parallel trends assumption in words and formally
- Pre-trends evidence (event study plot reference)
- If staggered treatment: explain the estimator choice (Callaway-Sant'Anna, Sun-Abraham, etc.) and why naive TWFE is inappropriate
- Never-treated vs. not-yet-treated comparison group -- which and why

**Instrumental Variables:**
- Instrument description and institutional motivation (why it's as-good-as-random)
- Exclusion restriction -- state it, explain why it holds, acknowledge what would violate it
- First stage strength (F-statistic, effective F)
- LATE interpretation -- who are the compliers? Is LATE the policy-relevant parameter?
- Monotonicity -- state and justify

**Regression Discontinuity:**
- Running variable and cutoff
- Bandwidth selection method (CCT, IK, or cross-validation)
- Continuity assumption -- what would violate it
- Manipulation tests (McCrary/Cattaneo density test)
- Covariate balance at the cutoff
- Visual evidence (RD plot reference)

**Event Study:**
- Event definition and timing
- Pre-period length and why it's sufficient
- Reference period choice
- Dynamic effects interpretation -- distinguish anticipation from pre-trends
- Binning of distant leads/lags if needed

### Structural: Model + Estimation

**Model section:**
1. **Environment** -- Agents, timing, information structure (1 paragraph)
2. **Preferences / technology** -- Functional forms with economic justification for each
3. **Decision problem** -- Agent's optimization, stated formally
4. **Equilibrium concept** -- Nash, competitive, Walrasian -- state and justify
5. **Key predictions** -- What the model implies that's testable or policy-relevant

**Estimation section:**
1. **Identification argument** -- Which moments identify which parameters. "The [variation] in the data pins down [parameter] because [logic]."
2. **Estimation method** -- MLE, GMM, simulated method of moments, indirect inference -- explain the choice
3. **Computational details** -- Optimization algorithm, starting values, convergence criteria (brief -- not a CS paper)
4. **Standard errors** -- How computed (delta method, bootstrap, outer product of gradients)

### Theory + Empirics: Model + Empirical Tests

**Model section:** Same as structural, but end with:
- **Testable predictions** -- Numbered propositions or hypotheses, each linked to an observable pattern

**Empirical section:** For each prediction:
1. State the prediction
2. Describe the test (regression, comparison, event study)
3. Present result
4. Discuss whether the model is supported or refuted

### Descriptive / Measurement

No separate strategy section. The contribution is in the data construction (already expanded above) and the presentation of facts in Results.

---

## Results (800--1500 words)

**Reduced-form:**
1. **Result statement** -- Main specification, lead with the number
2. **Economic significance** -- What does the magnitude mean in practice?
3. **Comparison** -- How does this relate to prior estimates?
4. **Heterogeneity** -- Who is affected more or less?
5. **Robustness narration** -- What doesn't change the result?

How to narrate by output type:
- **Regression table:** Lead with the preferred specification. "Column 3, which includes [controls/FE], shows [effect]. Adding [X] in Column 4 does not change the estimate."
- **Event study figure:** "Figure N shows [pattern]. The pre-period coefficients are close to zero [confirming parallel trends]. The effect appears in period [T] and [persists/fades/grows]."
- **IV results:** Present first stage, reduced form, and 2SLS together. "The first stage F-statistic is [X]. The reduced-form effect is [Y]. The 2SLS estimate implies [Z], consistent with a LATE of [interpretation]."
- **RD results:** "Figure N shows the discontinuity visually. The local polynomial estimate is [X] (bandwidth [B], chosen by [method]). The effect is robust to alternative bandwidths (Table N)."

**Structural:**
1. **Parameter estimates** -- Table of estimated parameters with standard errors. Interpret each economically ("the estimated risk aversion coefficient implies...")
2. **Model fit** -- How well does the estimated model match the data? Compare predicted vs. actual moments.
3. **Counterfactual simulations** -- The payoff. "We simulate [policy change]. The model predicts [outcome with magnitude]."
4. **Welfare** -- Consumer surplus, total surplus, distributional effects of the counterfactual
5. **Sensitivity** -- How do counterfactual results change with alternative parameter values?

**Theory + empirics:**
1. **Prediction-by-prediction results** -- For each testable prediction, state it, present the evidence, assess support
2. **Where the model works** -- Which predictions hold, and how strongly
3. **Where it doesn't** -- Which predictions fail, and what that implies for the theory
4. **Revised understanding** -- What we learn about the mechanism from the combined evidence

**Descriptive / measurement:**
1. **Key facts** -- Numbered, each with magnitude and units. Lead with the most important.
2. **Decompositions** -- Break down variation (across groups, over time, within units)
3. **Correlations and patterns** -- What predicts the measure? What moves with it?
4. **Comparison to existing measures** -- If replacing or improving on existing data, show the difference matters
5. **Implications** -- What do these facts imply for theory or policy?

---

## Conclusion (500--700 words)

**Common backbone:**
1. **Restatement** -- Main finding with effect size (one paragraph)
2. **Qualification** -- Where this doesn't generalize

**Type-specific endings:**

**Reduced-form:**
3. **Policy implications** -- What should change based on these results?
4. **Future work** -- Brief, one paragraph

**Structural:**
3. **Counterfactual implications** -- What the simulations imply for policy design
4. **Model limitations** -- What the model abstracts from, and whether it matters
5. **Future extensions** -- What would a richer model capture?

**Theory + empirics:**
3. **What the model gets right and wrong** -- Honest assessment
4. **Implications for theory** -- How should we revise our understanding?
5. **Future work** -- What would a better test or richer model look like?

**Descriptive / measurement:**
3. **What changes** -- How should these facts revise existing beliefs?
4. **Agenda** -- What questions can now be answered with this data/measure?

---

## Section Length Summary

| Section | Length | Reduced-Form | Structural | Theory+Empirics | Descriptive |
|---------|--------|-------------|-----------|----------------|-------------|
| Introduction | 1000-1500 | ...preview, result, contribution | ...model preview, counterfactual, contribution | ...theory preview, test result, contribution | ...data innovation, key fact, contribution |
| Data | 800-1200 | Treatment, outcome, controls | Moments that identify parameters | Standard | 1200-1800 (core contribution) |
| Strategy/Model | 800-1500 | Design-specific (DiD/IV/RDD/ES) | Environment, decisions, equilibrium, estimation | Model, propositions, tests | N/A (merged into Data) |
| Results | 800-1500 | Main spec, robustness, heterogeneity | Estimates, model fit, counterfactuals, welfare | Prediction-by-prediction evidence | Key facts, decompositions, implications |
| Conclusion | 500-700 | Policy implications | Counterfactual implications + model limitations | What model gets right/wrong | Research agenda enabled by new data |
| Abstract | 100-150 | Question, design, finding with magnitude | Question, model, counterfactual finding | Question, prediction, test result | Question, measurement, key fact |

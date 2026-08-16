# Defending Linearity in Labor Economics: Recent Examples and a Testing Playbook

## Executive summary

Recent labor-economics papers in top general-interest and top labor-field journals commonly justify linear functional forms by **putting a flexible “shape check” front-and-center**—usually a **binscatter/dose–response visualization on residualized variables**, often accompanied by **splines or binned (piecewise) specifications** that are interpreted as tests of whether the linear specification is being driven by outliers or hidden nonlinearities. citeturn18view0turn31view0turn36view0turn28view0

The best “templates” you can emulate for a **connectivity → wages** claim are:

- **Residualized binscatter + linear overlay** (and an explicit written conclusion that the relationship is “approximately linear” / “cannot reject linear”). This is very explicit in entity["organization","Review of Economics and Statistics","econ journal mit press"] labor work on smoke exposure and earnings. citeturn18view0turn18view3  
- **Spline vs. OLS comparison with confidence bands** (showing the spline lies within the OLS CI over the observed support). This is explicit in entity["organization","Journal of Labor Economics","labor econ journal"] work on GPA signals and earnings. citeturn36view0turn37search5  
- **Binning the regressor and plotting binned coefficients** as a functional-form robustness check (a clean way to show monotonicity and “near-linearity” without committing to global polynomials). This is explicit in the Facebook-ties labor paper. citeturn31view0  
- **Piecewise linear splines for time patterns / trend breaks** (if you need to defend linearity in time trends, exposure-time profiles, or policy timing). citeturn24view0

What follows: (i) a curated set of **published** examples (last decade, labor topics) with the **exact diagnostics** authors used, (ii) a cross-paper methods table, and (iii) a concrete **diagnostic + figure sequence** you can adapt to your unionspillovers paper, plus R/Stata snippets.

## Search frame and inclusion rules

Scope was **labor-economics papers published roughly within the last decade** (anchored to today: 2026-04-15) in the user-specified journal set: top general-interest journals (e.g., entity["organization","Quarterly Journal of Economics","econ journal harvard"]; also sought entity["organization","American Economic Review","economics journal"]) and top labor-field journals (especially entity["organization","Journal of Labor Economics","labor econ journal"], and labor-focused articles in entity["organization","Review of Economics and Statistics","econ journal mit press"]). Papers were retained only when authors **explicitly** did at least one of: (a) **state** that a relationship is approximately linear / cannot reject linearity, (b) compare to **splines / nonparametric** fits, or (c) implement a **binning/functional-form robustness** aimed at the regressor–outcome shape. citeturn18view0turn31view0turn36view0turn24view0turn6view2

Access constraints (publisher gates) were handled by prioritizing **primary PDFs** hosted on author sites, entity["organization","National Bureau of Economic Research","research org us"], or entity["organization","IZA Institute of Labor Economics","labor research institute"], plus publication metadata pages (e.g., RePEc listings) when needed for journal/year confirmation. citeturn17view0turn37search5turn16search4turn36view0

## Examples of explicit linearity defenses and tests in recent labor papers

### Wildfire smoke exposure and earnings: residualized dose–response binscatter

**Citation.** entity["people","Mark Borgschulte","economist"], entity["people","David Molitor","economist"], and entity["people","Eric Yongchen Zou","economist"]. “Air Pollution and the Labor Market: Evidence from Wildfire Smoke.” Published in entity["organization","Review of Economics and Statistics","econ journal mit press"] 106(6), 2024 (NBER WP 29952 version). citeturn16search4turn17view0

**Context (1–2 sentences).** The paper uses geographically dispersed wildfire smoke as plausibly exogenous air-pollution shocks to estimate impacts on county-level earnings and labor market outcomes. citeturn17view0

**Variable pair tested.** Cumulative smoke exposure intensity (days of wildfire smoke in a quarter/year) vs. labor-market outcomes (e.g., earnings), plus smoke → PM2.5 in the first stage. citeturn18view0turn18view1

**Diagnostics/tests/plots used to defend linearity.** The authors implement a *“nonlinear specification”* as a direct **dosage/shape test**: they (i) **residualize** outcomes and smoke exposure by fixed effects (Frisch–Waugh–Lovell style), (ii) form **ten equal bins** of residualized smoke, (iii) plot mean residual outcomes by bin (a **decile binscatter**) and overlay the **linear fit line** whose slope equals the OLS coefficient, then interpret whether the nonlinear pattern deviates materially from linear. citeturn18view1turn18view3

**Robustness checks connected to functional form.** They explicitly interpret the binscatter as a check that the estimated average effect is not driven by extreme events; they report that the patterns are “approximately linear” for PM2.5 and earnings and that they “cannot reject a linear relationship” for employment/LFP as well. citeturn18view0turn18view1 They also report extensive additional specification/robustness checks (alternate smoke definitions, flexible weather controls, fixed-effects strategies, annual aggregation, levels vs first differences, county time trends, clustering). citeturn18view0

**Conclusion on linearity adequacy.** They conclude the earnings (and first-stage) dose–response is **approximately linear** in smoke days, supporting a linear marginal effect interpretation. citeturn18view0turn18view1

### Job training duration as a dose: binscatter with data-driven polynomial/smoothness and a log-linear test

**Citation.** entity["people","Anna Aizer","economist"], entity["people","Nancy Early","economist"], entity["people","Shari Eli","economist"], entity["people","Guido Imbens","economist causal inference"], entity["people","Keyoung Lee","economist"], entity["people","Adriana Lleras-Muney","economist"], and entity["people","Alexander Strand","economist"]. “The Lifetime Impacts of the New Deal’s Youth Employment Program.” entity["organization","Quarterly Journal of Economics","econ journal harvard"] 139(4), 2024. citeturn25view0turn27view0

**Context (1–2 sentences).** The paper studies dose–response-style effects of **program duration** in the Civilian Conservation Corps on long-run outcomes such as longevity and lifetime earnings. citeturn25view0turn28view0

**Variable pair tested.** Training/service duration (years) vs longevity (log age at death) and other long-run outcomes (including lifetime earnings measures). citeturn25view0turn28view2

**Diagnostics/tests/plots used to defend linearity.** For longevity they present **binscatter plots controlling for birth year** using binscatter methodology associated with Cattaneo et al.; they **fix the number of bins (20)** but allow **polynomial approximation and smoothness** to be chosen by the algorithm between 1 and 3. They then state that the results indicate they “cannot reject a **log-linear** relationship” between duration and longevity. citeturn28view0turn28view3

**Robustness checks connected to functional form.** They note an alternative binscatter configuration: fixing polynomial approximation and smoothness at 1 and letting the algorithm choose an “optimal bandwidth,” and state the results are robust across these binscatter specifications. citeturn28view3

**Conclusion on linearity adequacy.** Within the observed support, they treat a **log-linear** specification (log death age on duration) as adequate and proceed with parametric modeling consistent with that shape. citeturn28view0turn28view3

### Social-network tie strength and job transmission: explicit nonparametric check yielding “roughly linear,” plus binned-coefficient shape plot

**Citation.** entity["people","Laura K. Gee","economist"], entity["people","Jason Jones","social scientist"], and entity["people","Moira Burke","researcher"]. “Social Networks and Labor Markets: How Strong Ties Relate to Job Finding on entity["company","Facebook","social network company"]’s Social Network.” entity["organization","Journal of Labor Economics","labor econ journal"] 35(2), 2017. citeturn30view0turn31view0

**Context (1–2 sentences).** Using large-scale online-network data, the paper studies how **tie strength** relates to the probability that a user works with a specific friend (job transmission), engaging the “weak ties” hypothesis in a labor-market setting. citeturn30view0turn31view0

**Variable pair tested.** Tie-strength measure with friend \(T_{ik}\) vs sequential job indicator \(J_{ik}\) (probability of eventually working with friend \(k\)). citeturn31view0

**Diagnostics/tests/plots used to defend linearity.** The paper explicitly flags potential **nonmonotonicity** and then states that **nonparametric models yield a roughly linear relationship** (referencing an appendix figure). citeturn31view0 They further justify use of a linear probability model for interpretability and note a logit yields the same sign/significance in an appendix table. citeturn31view0

**Robustness checks connected to functional form.** They conduct a *functional-form robustness exercise*: they discretize each tie-strength measure into “roughly equally sized bins” (excluding zero), estimate a model with these bins and user fixed effects, and **plot the coefficients against tie strength**, concluding the relationship is “positive and generally linear.” citeturn31view0

**Conclusion on linearity adequacy.** They conclude that, over the observable range and conditional structure, a **linear model is a reasonable summary**, consistent with nonparametric and binned-coefficient evidence. citeturn31view0

### GPA as a signal and earnings: spline-vs-OLS overlay showing “fairly linear across the scale”

**Citation.** entity["people","Anne Toft Hansen","economist"], entity["people","Ulrik Hvidman","economist"], and entity["people","Hans Henrik Sievertsen","economist"]. “Grades and Employer Learning.” entity["organization","Journal of Labor Economics","labor econ journal"] 42(3), 2024 (published version; IZA DP 14200 working-paper version contains the functional-form discussion). citeturn37search5turn36view0

**Context (1–2 sentences).** Exploiting an exogenous grading-scale reform at Danish universities, the paper estimates returns to GPA at labor-market entry and how employer learning attenuates information content over time. citeturn36view0turn37search5

**Variable pair tested.** Reform-induced GPA variation vs log earnings (year after graduation), with broader dynamics over early career. citeturn36view0

**Diagnostics/tests/plots used to defend linearity.** The authors explicitly state they have been assuming a **linear** relationship between reform-induced GPA variation and log earnings, then motivate possible nonlinearity/asymmetry. They present a figure estimating the relationship using a **natural cubic spline with three knots** on residualized earnings and residualized GPA shock, alongside the linear OLS relationship and its 95% CI; they report the spline is always within the CI of the linear specification and interpret this as evidence that returns are “fairly linear across the entire scale.” citeturn36view0

**Robustness checks connected to functional form.** The same section references systematic variation of functional forms \(f(\cdot)\) (rows labeled as alternate ways to capture \(f(GPA13)\), plus a “less parametric approach”), reflecting a broader strategy of checking sensitivity to functional form assumptions. citeturn36view0

**Conclusion on linearity adequacy.** For the treatment-support they study, they conclude the earnings response to GPA shocks is **fairly linear**, supporting their linear baseline. citeturn36view0

### Policy timing patterns: three-part linear spline to summarize event-study noise and formalize trend-break tests

**Citation.** entity["people","Martha J. Bailey","economist"], entity["people","Thomas E. Helgerman","economist"], and entity["people","Bryan A. Stuart","economist"]. “How the 1963 Equal Pay Act and 1964 Civil Rights Act Shaped the Gender Gap in Pay.” entity["organization","Quarterly Journal of Economics","econ journal harvard"] 139(3), 2024. citeturn22view0turn24view0

**Context (1–2 sentences).** The paper studies how mid-1960s federal antidiscrimination statutes affected women’s wages and the gender pay gap, using designs that relate policy exposure to wage changes. citeturn22view0turn24view0

**Variable pair tested.** Time (relative to policy enactment) interacted with policy-exposure group vs log weekly wages (and related outcomes). citeturn24view0

**Diagnostics/tests/plots used to defend linearity.** They introduce a **three-part linear spline** in time with knots in 1964 and 1968, explicitly as a parsimonious summary of a noisier event-study while preserving flexibility. They emphasize it provides a “parsimonious method to test and, if necessary, adjust for pre-trends” and that certain spline coefficients allow “a formal test for a trend break.” citeturn24view0

**Robustness checks connected to functional form.** Conceptually, this is a functional-form robustness device: it reduces sensitivity to noise in single-year coefficients and formalizes a small set of slope parameters (pre-trend slope, short-run post slope, longer-run post slope). citeturn24view0

**Conclusion on linearity adequacy.** They treat a **piecewise linear** time path as an adequate—and more precise—summary for inference about pre-trends and timing breaks relative to policy implementation. citeturn24view0

### Baseline nonlinear controls and “approximately linear” pretrend adjustment: two common ways labor papers handle shape concerns

**Citation.** entity["people","Conrad Miller","economist"]. “When Work Moves: Job Suburbanization and Black Employment.” entity["organization","Review of Economics and Statistics","econ journal mit press"] 105(5), 2023. citeturn5view1turn6view2

**Context (1–2 sentences).** The paper studies job suburbanization and racial gaps in employment and earnings, addressing competing explanations such as differential trends and baseline differences. citeturn5view1turn6view2

**Variable pair tested.** Two functional-form issues are made explicit:  
- Baseline outcome level (baseline employment/earnings) vs subsequent growth (because growth may depend nonlinearly on baseline). citeturn45view2turn45view0  
- Differential pretrends over time (where evidence suggests an approximately linear differential trend, motivating linear-trend adjustments). citeturn6view2

**Diagnostics/tests/plots used to defend linearity.** The paper explicitly motivates allowing nonlinearity in baseline relationships by specifying \(f(\cdot)\) as a **quadratic function** in baseline employment rates or log earnings, because growth may depend nonlinearly on the baseline. citeturn45view2turn45view0 Separately, in the pretrend discussion the author notes evidence that a differential trend is “approximately linear” and estimates an alternative specification allowing a **linear trend** specific to relocating establishments. citeturn6view2

**Conclusion on linearity adequacy.** The paper (i) treats quadratic baseline controls as a safeguard against misspecifying baseline-growth mapping, and (ii) uses linear-trend adjustments as an interpretation/robustness device where pretrends look approximately linear. citeturn45view2turn6view2

## Comparison table of linearity-defense methods across papers

| Paper | Journal | Year | Variable pair tested | Diagnostics/tests used to defend linearity | Robustness checks tied to functional form | Conclusion |
|---|---:|---:|---|---|---|---|
| Wildfire smoke & labor outcomes | REStat | 2024 | Smoke days → earnings (and smoke → PM2.5) | Residualized **decile binscatter** (“nonlinear specification”) with **linear fit overlay**; interpret approximate linear dose–response citeturn18view1turn18view0 | Many spec checks; binscatter used to argue not driven by extremes citeturn18view0 | Earnings (and first stage) “approximately linear”; cannot reject linear for other outcomes citeturn18view0 |
| CCC duration & longevity | QJE | 2024 | Duration → log death age | **Binscatter** controlling for cohort with algorithmic choice of polynomial/smoothness; explicit “cannot reject **log-linear** relationship” statement citeturn28view0turn28view3 | Alternative binscatter configuration (fix degree/smoothness; bandwidth chosen) citeturn28view3 | Treat log-linear as adequate; proceed with parametric models consistent with that shape citeturn28view0 |
| Facebook tie strength & job transmission | JLE | 2017 | Tie strength \(T_{ik}\) → job-with-friend \(J_{ik}\) | Explicit statement: nonparametric models yield “roughly linear”; also compare LPM vs logit for sign/significance citeturn31view0 | **Binned** tie-strength coefficients plotted against tie strength, “positive and generally linear” citeturn31view0 | Linear model as interpretable summary is supported by nonparametric/binned checks citeturn31view0 |
| GPA reform shock & entry earnings | JLE | 2024 | Reform-induced GPA → log earnings | **Natural cubic spline** (3 knots) vs OLS line + 95% CI on residualized variables; spline remains within CI citeturn36view0turn37search5 | Multiple alternate \(f(\cdot)\) choices; “less parametric” alternative referenced citeturn36view0 | Returns “fairly linear across the entire scale” of the shock citeturn36view0 |
| Equal Pay Act timing | QJE | 2024 | Time × exposure → log wages | **Three-part linear spline** in time (knots 1964/1968) to summarize event study; formal pretrend and trend-break tests via spline coefficients citeturn24view0 | Spline as robustness/precision enhancement relative to noisy year-by-year estimates citeturn24view0 | Piecewise linear trends treated as adequate, transparent summary for inference citeturn24view0 |
| Job suburbanization & racial outcomes | REStat | 2023 | Baseline outcomes → growth; pretrend linearity | Explicit quadratic baseline control \(f(\cdot)\) to allow nonlinear baseline-growth mapping; explicit “approximately linear” differential trend motivates linear-trend adjustment citeturn45view2turn6view2 | Sensitivity to inclusion of baseline earnings; alternative trend specification for relocators citeturn6view2turn45view3 | Quadratic baseline terms and linear-trend adjustments are used to address functional-form concerns citeturn45view2turn6view2 |

## Recommended diagnostics and figures for a unionspillovers paper claiming connectivity → wages is linear

Your goal is not to “prove” linearity in a metaphysical sense; it is to show—in a way that referees recognize—that (i) the data do not demand strong curvature **within the common support**, and (ii) your key conclusions are **robust** to flexible alternatives that would have captured meaningful departures from linearity if present. The papers above give you several referee-friendly patterns: residualized dose–response binscatters, spline-vs-OLS overlays, and binned-coefficient plots. citeturn18view1turn36view0turn31view0turn28view0

### A practical figure/test bundle (what to run and what to show)

**Data-prep choices that matter for “linearity” claims**
- Put the wage outcome in the form that matches your theory and the paper’s main estimand: **log wages** are common when interpreting percent effects; **levels** matter if welfare/rents are in dollars. If your connectivity measure is heavy-tailed or has zeros, consider reporting both **levels** and a monotone transform (e.g., `log1p(connectivity)`), then show the shape checks under both. (This mirrors the idea in several papers that the relevant functional form is part of the estimand choice rather than merely a statistical convenience.) citeturn28view0turn18view0

**Figure set**
- **Figure 1 (Raw relationship; sanity check).** Scatter/binscatter of wages vs connectivity with:
  - 20 bins (or a data-driven choice),
  - a fitted linear line,
  - and a lowess/local-linear smooth.  
  This is the “first glance” figure; don’t oversell it because it ignores controls and fixed effects.

- **Figure 2 (Residualized binscatter; your main shape defense).** Do a Frisch–Waugh–Lovell residualization:
  1) residualize wages on your controls and fixed effects,  
  2) residualize connectivity on the same controls and fixed effects,  
  3) binscatter residualized wage against residualized connectivity, overlay the linear fit.  
  This mirrors the REStat wildfire-smoke approach where the “nonlinear specification” is exactly a residualized dose–response check. citeturn18view1turn18view3

- **Figure 3 (Spline overlay vs OLS + CI).** Plot:
  - OLS fit with 95% CI,
  - a natural cubic spline fit (e.g., 3–5 knots at quantiles) with its own CI,
  - on the same residualized axes.  
  This directly emulates the “spline stays within OLS CI” argument in JLE. citeturn36view0

- **Figure 4 (Binned-coefficient plot).** Bin connectivity into, say, 10–20 bins (excluding sparse tails if necessary). Estimate a model with bin dummies (with FE/controls), plot coefficients vs bin midpoints. This is essentially the JLE Facebook-ties functional-form robustness: “plot coefficients against tie strength” to show the relationship is “generally linear.” citeturn31view0

**Formal(ish) tests you can report in appendix**
- **Quadratic/cubic augmentation tests.** Add \(connectivity^2\) (and maybe \(connectivity^3\)) to your baseline, cluster as usual, and report:
  - joint test \(H_0:\beta_2=\beta_3=0\),
  - whether the implied curvature is economically meaningful over the support.  
  This is a lightweight complement to the graphical tests and aligns with the spirit of papers that explicitly guard against nonlinear baseline relationships with polynomial terms. citeturn45view2
- **Piecewise linear spline “slope break” tests.** If you choose knots at, e.g., the 25th/50th/75th percentiles, you can test equality of adjacent slopes. This is the same logic as using spline parameters for “trend breaks,” applied cross-sectionally in connectivity instead of time. citeturn24view0
- **Cross-validated fit comparison.** If feasible, compare linear vs spline vs local-polynomial predictive loss under cross-validation (or compare AIC/BIC for nested parametric variants). This isn’t showcased explicitly in the example papers above, but it is a standard econometric complement to the binscatter/spline checks those papers foreground. citeturn28view3turn18view1

### Implementation details that tend to satisfy referees

**Binscatter design choices**
- Start with **20 bins** (common, easy to read), then show robustness to 10 and 30 bins in appendix. The CCC paper explicitly fixes bins at 20 in key plots (and discusses alternative tuning), which gives you a precedent for “20 as a default.” citeturn28view0turn28view3  
- Use **residualized variables** (FWL) when your baseline has many controls/fixed effects; the wildfire smoke paper describes exactly that procedure as a nonlinear/dose-response check. citeturn18view1turn18view3

**Splines**
- For a connectivity regressor, **natural cubic splines** with **3 knots** is a very defensible starting point (JLE example). citeturn36view0  
- Choose knots at quantiles (e.g., 0.2/0.5/0.8) to avoid knots in sparse regions. Then add a sensitivity: 4–5 knots (0.1/0.3/0.5/0.7/0.9) or a piecewise linear spline.

**Lowess/local polynomial**
- Use lowess as a **visual diagnostic**, not the basis for your main coefficient. Use a main span of ~0.5 and show 0.3/0.7 in appendix; or use local linear regression with bandwidth chosen by a rule-of-thumb and then perturb.  
- Interpret only within common support; if connectivity has extreme right tail, either trim/winsorize for the plot (and say so) or use quantile-binning that keeps the picture readable.

**When “linearity” is really about time or exposure intensity**
- If you have policy timing (e.g., post-unionization exposure over time), consider a **piecewise linear spline in time** as a more precise replacement for noisy year-by-year event-study coefficients, explicitly framed as a pretrend/trend-break device (QJE precedent). citeturn24view0

image_group{"layout":"carousel","aspect_ratio":"16:9","query":["binscatter residualized scatter plot example economics","lowess smoother scatter plot example","natural cubic spline regression plot example","partial residual plot example"],"num_per_query":1}

## R and Stata implementation snippets and a referee-friendly testing sequence

### R snippets (minimal dependencies; you can swap in your FE estimator)

```r
# Core packages
library(ggplot2)
library(splines)
library(lmtest)

# Suppose you have: y = log_wage, x = connectivity, controls in data frame df
# and you want a residualized (FWL) binscatter.

# 1) Residualize y and x on the same controls + FE (illustrative; replace with fixest::feols for high-dim FE)
m_y <- lm(log_wage ~ controls1 + controls2 + factor(state) + factor(year), data = df)
m_x <- lm(connectivity ~ controls1 + controls2 + factor(state) + factor(year), data = df)
df$y_res <- resid(m_y)
df$x_res <- resid(m_x)

# 2) Binscatter (20 quantile bins) + linear fit + LOESS
df$bin <- cut(df$x_res,
              breaks = quantile(df$x_res, probs = seq(0, 1, length.out = 21), na.rm = TRUE),
              include.lowest = TRUE)

bin_df <- aggregate(cbind(y_res, x_res) ~ bin, data = df, FUN = mean)

ggplot(df, aes(x = x_res, y = y_res)) +
  geom_point(alpha = 0.05) +
  geom_point(data = bin_df, size = 2) +
  geom_smooth(method = "lm", se = TRUE) +
  geom_smooth(method = "loess", span = 0.5, se = FALSE) +
  labs(x = "Residualized connectivity", y = "Residualized log wage")

# 3) Spline-vs-linear overlay on residualized data
m_lin   <- lm(y_res ~ x_res, data = df)
m_spline <- lm(y_res ~ ns(x_res, df = 4), data = df)  # df=4 is a common start (3 knots-ish)

# Prediction grid
grid <- data.frame(x_res = seq(quantile(df$x_res, 0.01, na.rm=TRUE),
                               quantile(df$x_res, 0.99, na.rm=TRUE),
                               length.out = 200))
grid$lin_hat <- predict(m_lin, newdata = grid)
grid$spl_hat <- predict(m_spline, newdata = grid)

ggplot(df, aes(x = x_res, y = y_res)) +
  geom_point(alpha = 0.03) +
  geom_line(data = grid, aes(y = lin_hat), linewidth = 1) +
  geom_line(data = grid, aes(y = spl_hat), linetype = "dashed", linewidth = 1) +
  labs(x = "Residualized connectivity", y = "Residualized log wage")

# 4) Quadratic test
m_quad <- lm(y_res ~ x_res + I(x_res^2), data = df)
anova(m_lin, m_quad)  # nested F-test

# 5) Ramsey RESET (on residualized regression)
resettest(m_lin, power = 2:3, type = "fitted")  # adds fitted^2, fitted^3
```

### Stata snippets (including FWL residualization and spline checks)

```stata
* Assume logwage is outcome, conn is connectivity.
* controls: x1 x2 ...; fixed effects: firm_id and year (examples).
* If you use reghdfe:
* ssc install reghdfe, replace

* 1) Residualize logwage and conn on the same controls + FE (FWL)
reghdfe logwage x1 x2, absorb(firm_id year) resid(y_res)
reghdfe conn    x1 x2, absorb(firm_id year) resid(x_res)

* 2) Binscatter-like plot: quantile bins + mean outcomes
xtile bin = x_res, nq(20)
collapse (mean) y_res x_res, by(bin)
twoway ///
  (scatter y_res x_res) ///
  (lfit y_res x_res) ///
  (lowess y_res x_res, bwidth(0.5)), ///
  ytitle("Residualized log wage") xtitle("Residualized connectivity")

* 3) Spline regression (piecewise linear example with knots at quantiles)
* Back to the full data; re-load if needed
use yourdata, clear
reghdfe logwage x1 x2, absorb(firm_id year) resid(y_res)
reghdfe conn    x1 x2, absorb(firm_id year) resid(x_res)

summ x_res, detail
local k1 = r(p25)
local k2 = r(p50)
local k3 = r(p75)

mkspline s1 `k1' s2 `k2' s3 `k3' s4 = x_res
reg y_res s1 s2 s3 s4
test s2 = s1  // example slope equality test (adjust as appropriate)

* 4) Quadratic / cubic and joint test
reg y_res c.x_res##c.x_res
test c.x_res#c.x_res

reg y_res c.x_res##c.x_res##c.x_res
test c.x_res#c.x_res c.x_res#c.x_res#c.x_res

* 5) Ramsey RESET after the residualized linear regression
reg y_res x_res
estat ovtest
```

### Mermaid flowchart of a testing sequence you can cite in your appendix

```mermaid
flowchart TD
  A[Define main estimand: log wage vs wage level; choose connectivity scale] --> B[Check support & tails; decide trimming/winsorization for plots]
  B --> C[Raw plot: binscatter + linear fit + lowess]
  C --> D[FWL residualization: partial out controls + FE from y and x]
  D --> E[Main shape plot: residualized binscatter + linear overlay]
  E --> F[Spline overlay: natural cubic spline vs OLS + CI]
  F --> G[Parametric curvature: add x^2 (and x^3), joint tests]
  G --> H[Binned-coefficient plot: bin x, estimate bin dummies, plot coefficients]
  H --> I{Any meaningful nonlinearity?}
  I -->|No| J[Defend linear baseline; report plots/tests; keep linear for power/interpretability]
  I -->|Yes| K[Consider spline/piecewise as main; or report nonlinear estimates alongside linear]
```


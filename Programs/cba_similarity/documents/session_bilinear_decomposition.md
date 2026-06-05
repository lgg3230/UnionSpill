# CBA Similarity Spillover — Full Documentation

This document records, in long form, the CBA similarity spillover
exercise developed for the *Outside Options and Collective Bargaining
Spillovers* paper. It is internal to the authors. The corresponding
paper subsection will be considerably shorter and will draw on the
material here only for the parts that survive editing for length and
publication style. The aim of this document is to retain the reasoning
that produced the numbers we eventually report: what we measured, why
we measured it that way, what we tried first and abandoned, and how to
read the final coefficient tables and figures.

The document is organized in three parts. Part I introduces the CBA
similarity exercise itself: how clause vectors and the partner reference
are constructed, the four similarity measures we use, the headline
finding that more-connected untreated firms drift toward their treated
partners' contracts post-reform, and the parallel finding that the same
firms also drift toward the global average treated CBA. Part II tackles
the follow-up question — when the two clause vectors converge, which
side is actually moving — by running each of the four similarity
measures against three counterfactual pairings of focal and reference
that hold one side fixed at its last pre-reform value. The five
regression outcomes built from those three similarities admit an
algebraic and a coefficient identity that pin down the contribution of
each side. Part III discusses what mechanisms are consistent with the
resulting pattern, in light of the rest of the paper's findings.

An earlier version of Part II built a separate exercise around the
bilinear inner product $u_t \cdot T_t$ and its share-normalized
counterpart, exploiting that the inner product decomposes algebraically
into focal, partner, and joint pieces. That exercise is reported as an
appendix robustness rather than in the main text: it asks the reader
to internalize a new (non-standard) outcome, whereas the ordered
decomposition described here keeps the outcome inside the four
similarity measures introduced in Part I.

# Part I — Convergence in Clause Content

## 1. Motivation

Section 5 of the paper documents two consistent facts about spillover
firms — untreated establishments connected to directly treated firms
via worker flows. Spillover firms experience positive wage gains, with
a cross-firm wage elasticity of roughly 0.2, but no measurable change
in the *count* of CBA clauses they negotiate post-reform. The null on
the aggregate count survives disaggregation by clause type: when we
estimate the same DiD specification separately on the number of
clauses within each of the registry's broad clause-type categories, no
single category exhibits a significant connectivity-driven response.
The reform did not shift the count of any specific class of clauses
*uniformly* at connected firms.

This last statement is more subtle than the aggregate null might
suggest, and the subtlety is what motivates the present exercise.
What the disaggregated counts rule out is a *common* clause-type shift
across spillover firms: a redistribution that, on average, every
connected firm undergoes in the same direction. It does not rule out
firm-specific shifts in clause content. Different spillover firms can
move their CBAs toward different parts of the clause space without
the average count of any one clause type changing on net. To detect
such firm-specific composition shifts, we need an outcome that is
itself firm-specific — one that measures, for each focal firm, how
close its post-reform CBA sits to a reference *its own* treated peers
provide, rather than how much of any one clause type it has added on
average. The natural object is a similarity measure between each
focal firm's clause vector and a treated reference vector, with each
firm receiving its own reference. We construct such a measure below.

The exercise asks: for each untreated firm in the spillover sample, how
similar is the *content* of its CBA to a relevant reference of treated
firms' CBAs? We then run the same DiD specification as in the headline
spillover analysis, with this similarity measure as the outcome, to
test whether more-connected firms move toward treated content
post-reform. The exercise is silent on whether spillover firms are
negotiating *better* clauses; it asks only whether their clause set is
becoming more similar to that of their treated peers.

## 2. Construction of the Outcomes

**Clause vector.** Each CBA in the registry is annotated by the
filing parties into a fixed taxonomy of clause types. After restricting
to clause indicators that vary across our analysis sample, we retain
$K = 139$ clause types. For each firm $i$ and CBA bargaining round
$t \in \{1, \ldots, 6\}$, we construct a binary vector
\[
    u_{i,t} \;=\; \big(u_{i,t}^{(1)}, \ldots, u_{i,t}^{(K)}\big) \in \{0,1\}^K,
\]
where $u_{i,t}^{(k)} = 1$ if clause $k$ appears in the firm's CBA at
round $t$. Rounds 1 and 2 fall before the September 2012 reform; round
3 is each firm's first post-reform agreement; rounds 4–6 are subsequent
renewals.\footnote{The CBA round index is firm-specific. Two firms at
different points in their bargaining cycle can be in different rounds
at the same calendar date. The DiD uses a firm-specific post indicator
$\text{post}_t = \mathbb{1}\{t \ge 3\}$ to absorb this staggered
timing.} When more than one CBA covers the same firm-round, we take
the mean across CBAs, allowing $u_{i,t}^{(k)} \in [0,1]$.

**Partner reference (connectivity-weighted).** For each untreated focal
firm $i$, let $\mathcal{N}_i^{\text{tr}}$ denote the set of treated
firms with positive pre-treatment worker-flow connectivity to $i$, and
let $w_{ik}$ be the bilateral connectivity weight as defined in
equation (1) of the paper. The flow-weighted partner reference at
round $t$ is
\[
    T_{i,t} \;=\; \frac{\sum_{k \in \mathcal{N}_i^{\text{tr}}} w_{ik}\,u_{k,t}}
                            {\sum_{k \in \mathcal{N}_i^{\text{tr}}} w_{ik}}.
\]
$T_{i,t}$ is the typical clause profile of the treated firms with
which the focal exchanges workers. It is well-defined for every
untreated firm that has at least one treated worker-flow partner with
a CBA in round $t$; firms with no treated partners drop out of this
exercise mechanically.

**Average-treated reference.** As a complement, we also construct an
*unweighted* average treated CBA at each round,
\[
    \tilde T_t \;=\; \frac{1}{|\mathcal{T}_t|} \sum_{k \in \mathcal{T}_t} u_{k,t},
\]
where $\mathcal{T}_t$ is the set of directly treated firms with a CBA
in round $t$. $\tilde T_t$ depends on $t$ but not on $i$, so every
untreated firm with a CBA receives a reference vector. This widens
the analysis sample from the 1,652 establishments that have treated
worker-flow partners to the full 4,142 untreated establishments in
the balanced spillover panel.

**Why two references.** The connectivity-weighted reference is the
natural object if one believes that spillovers run firm-to-firm
through specific labor-market channels: each focal sees its own
weighted partner profile and is asked to converge toward *that*. The
average-treated reference instead asks whether the spillover shifts
firms toward the global treated CBA profile, irrespective of which
specific treated firms they share workers with. The two are
complementary: the first identifies a connection-specific channel,
the second tests the same question on the much larger sample of
untreated firms that have at least one CBA in the panel but no treated
worker-flow partners.

## 3. Similarity Measures

A similarity measure is a scalar function $S(u, T) \in [0, 1]$ that is
maximized when $u = T$. Different measures formalize "similarity"
differently, with the main axis of disagreement being how heavily they
penalize differences in *magnitude*. We use four measures, ordered
roughly from least to most magnitude-sensitive.

**Cosine similarity** $\cos(u, T) = (u \cdot T) / (\|u\| \|T\|)$. This
is the angle between the two vectors, treating them as directions in
$\mathbb{R}^K$. Rescaling either vector — for instance, doubling all
clause indicators (impossible here because they are binary, but the
intuition is the same for the share normalizations we use later) —
does not change the cosine. As a consequence, cosine treats two CBAs
with very different numbers of clauses as similar so long as the
clauses they contain are roughly proportional in distribution.

**Total variation similarity** $\operatorname{TV}(u, T) = 1 - \tfrac{1}{2}
\sum_k |u^{(k)} - T^{(k)}|$. After normalizing each vector to the
simplex, this is one minus the total variation distance between two
distributions. It is sensitive to differences in both the support and
the relative weights of the clause vectors.

**Bray-Curtis similarity** $\operatorname{BC}(u, T) = 1 - (\sum_k
|u^{(k)} - T^{(k)}|) / (\sum_k (u^{(k)} + T^{(k)}))$. Bray-Curtis
applies the same $L_1$ comparison as total variation but normalizes
by the joint $L_1$ norm of the two vectors $\sum_k (u^{(k)} + T^{(k)})$
rather than by the constant 2 implicit in $\operatorname{TV}$ after
simplex normalization. The two measures therefore coincide whenever
$u$ and $T$ are simplex-normalized, and they diverge when the two
vectors differ in total clause count: $\operatorname{BC}$ penalizes
that difference in clause count directly, $\operatorname{TV}$ removes
it by construction. A focal firm with 50 clauses and a partner
reference with 100 clauses can have a low Bray-Curtis similarity
even when the 50 are a subset of the 100.

**Ruzicka similarity** $\operatorname{Ruz}(u, T) = (\sum_k \min(u^{(k)},
T^{(k)})) / (\sum_k \max(u^{(k)}, T^{(k)}))$. Ruzicka, also known as
weighted Jaccard, is the most magnitude-sensitive of the four: an
imbalanced pair pays a penalty proportional to the gap between $u$ and
$T$ on every clause where they differ in magnitude.

Reporting all four lets us see which geometric feature is driving the
convergence. A result that appeared only in cosine would tell us the
convergence is angular — that focal and partner clause vectors are
becoming more proportionally aligned without any of the magnitude
margins responding. A result that appeared only in Bray-Curtis or
Ruzicka would tell us the opposite — that the convergence is being
driven by the focal and partner moving closer in total clause count or
in per-clause magnitude overlap, with angular alignment unchanged. A
result that appears in all four implicates each of the underlying
geometric features simultaneously, and rules out an interpretation
that hinges on any single one.

## 4. Specification and Identification

We use the same difference-in-differences specification as the headline
spillover analysis (Section 5.2 of the paper). For each focal firm $i$
and round $t$,
\[
    S_{it} \;=\; \alpha_i \;+\; \gamma_{j(i)t} \;+\; \delta_{r(i)t} \;+\; \mu_{m(i)t} \;+\; \mathbf{x}_i^{\prime}\boldsymbol{\theta}_t \;+\; \beta\,\big(\text{conn}_i \times \text{post}_t\big) \;+\; \varepsilon_{it},
\]
where $S_{it}$ is the similarity outcome of choice; $\alpha_i$ is an
establishment fixed effect; $\gamma_{j(i)t}$, $\delta_{r(i)t}$, and
$\mu_{m(i)t}$ are two-digit industry, microregion, and CBA filing-month
$\times$ period fixed effects; $\mathbf{x}_i$ is a vector of
pre-treatment quartile bins (in log employment, total worker flows,
and the pre-treatment similarity outcome itself) interacted with
period dummies; $\text{conn}_i$ is the focal firm's pre-treatment
worker-flow connectivity to treated establishments, normalized to
unity at the 90th percentile of the spillover sample; and
$\text{post}_t = \mathbb{1}\{t \ge 3\}$. Standard errors are clustered
at the establishment level. This is identical to the equation that
generates the headline wage spillover estimate; only the outcome
changes.

Identification rests on the same parallel-trends assumption as in the
main spillover analysis: absent the reform, more- and less-connected
untreated firms would have followed comparable trajectories in clause
content. We assess this by estimating the pre-trend variant of the
specification on the pre-reform window (rounds 1 vs. 2) and report the
placebo coefficient for each outcome.

## 5. Headline Results

Both reference choices deliver the same qualitative conclusion: more-
connected untreated firms move closer to treated CBAs after the
reform, and this convergence is detected by all four similarity
measures. We summarize the point estimates in Figure
\ref{fig:sim_headline_coefplot} and discuss the magnitudes below.

![Figure: similarity_headline_coefplot.pdf](../../../Graphs/cba_similarity/similarity_headline_coefplot.pdf)

**Connectivity-weighted partner reference.** Using $T_{i,t}$ — each
focal's flow-weighted profile of its specific treated partners — the
DiD coefficients on $\text{conn}_i \times \text{post}_t$ are positive
and significant across all four measures:
\[
\begin{array}{lll}
\text{Cosine:}            & \hat\beta = 0.0133^{\,***} & (\text{s.e. } 0.0039,\; \bar S = 0.41) \\
\text{Total variation:}   & \hat\beta = 0.0102^{\,***} & (\text{s.e. } 0.0031,\; \bar S = 0.31) \\
\text{Bray-Curtis:}       & \hat\beta = 0.0083^{\,***} & (\text{s.e. } 0.0028,\; \bar S = 0.31) \\
\text{Ruzicka:}           & \hat\beta = 0.0062^{\,**}  & (\text{s.e. } 0.0025,\; \bar S = 0.22)
\end{array}
\]
all estimated on 6,943 firm-round observations across 1,652
establishments, with pre-trend placebos that are small and (with the
exception of Ruzicka) insignificant.\footnote{The Ruzicka pre-trend is
$-0.0039$ ($p \approx 0.05$), opposite-signed from the post effect.
Because it is opposite-signed, it would attenuate the post estimate
rather than amplify it.} Magnitudes vary across measures roughly in
proportion to the baselines they sit on: cosine moves 3.2\% of its
baseline of 0.41, total variation 3.3\% of 0.31, Bray-Curtis 2.7\% of
0.31, Ruzicka 2.9\% of 0.22.

**Average-treated reference.** Using $\tilde T_t$ — the simple
unweighted average across all directly treated firms in round $t$ —
the same conclusion holds on the wider untreated panel:
\[
\begin{array}{lll}
\text{Cosine:}            & \hat\beta = 0.0030^{\,***} & (\text{s.e. } 0.0010,\; \bar S = 0.44) \\
\text{Total variation:}   & \hat\beta = 0.0019^{\,**}  & (\text{s.e. } 0.0009,\; \bar S = 0.27) \\
\text{Bray-Curtis:}       & \hat\beta = 0.0019^{\,**}  & (\text{s.e. } 0.0008,\; \bar S = 0.26) \\
\text{Ruzicka:}           & \hat\beta = 0.0012^{\,**}  & (\text{s.e. } 0.0005,\; \bar S = 0.16)
\end{array}
\]
all estimated on 19,693 firm-round observations across 4,142
establishments, with negligible pre-trends. The point estimates are
smaller than those obtained against the partner-specific reference,
which is what one would expect: a typical untreated firm sits at
roughly the same distance from any single treated firm as from the
unweighted average across all treated firms, but its connectivity-
weighted partner reference is a much more idiosyncratic, firm-specific
object that responds more strongly to firm-specific exposure.

**Reading the two together.** The fact that both reference choices
deliver positive, significant convergence across all four similarity
measures is what makes the spillover into clause *content* — as
distinct from clause *count* — a robust finding. It is not driven by
who specifically the focal firm shares workers with (the average-
treated specification removes that idiosyncrasy entirely), nor by any
single similarity measure's particular sensitivity to magnitudes
versus angles. The reform shifted the composition of CBAs at
spillover firms in a direction that the directly treated firms'
CBAs occupy more heavily than they did before; this is what every
combination of (reference, measure) registers.

The clause-count null reported in Section 5.2 of the paper is
therefore not in tension with this finding, but it is incomplete on
its own. Spillover firms did not negotiate *more* provisions after
the reform, but they did renegotiate *toward different* provisions —
specifically, toward the provisions emphasized by their treated
peers. We now ask which side of this convergence is doing the work.

# Part II — Who Moves? An Ordered Decomposition

## 6. The Question

The headline result tells us that the similarity between an untreated
firm's CBA and a treated reference rises with connectivity post-reform.
It does not tell us *which side moves*. Three alternatives are
consistent with the headline coefficient. First, the untreated firm
may drift toward what its treated partners' contracts contained before
the reform — in other words, the treated CBA is the destination and
the untreated firm is catching up. Second, the treated partners may
drift back toward what the untreated focal's contract contained before
the reform — in this case the untreated CBA is the destination. Third,
both sides may move simultaneously into a clause region that neither
was emphasizing pre-reform — a *shared destination* selected by the
reform itself rather than by either side's past contract.

The three alternatives have very different economic content. A
spillover concentrated on the focal side is consistent with imitation
of an established template: connected firms adopt clauses that their
treated peers had long featured. A spillover concentrated on the
partner side would imply that the reform tipped treated firms back
into provisions familiar to their untreated peers — essentially a
redistribution along a pre-existing gradient, with the untreated
contract as the anchor. A spillover dominated by joint motion would
imply that neither past contract is the destination, and would
instead point toward a new contractual equilibrium that the reform
itself, rather than any prior agreement, has selected. Distinguishing
these requires that we be able to attribute the headline coefficient
to each side separately. The remainder of Part II develops the
machinery to do so.

## 7. Three Counterfactual Similarities

We work within the four similarity measures already introduced in
Part I — cosine, total variation, Bray-Curtis, and Ruzicka — and do
not introduce any new outcome. For each focal firm $i$, CBA period
$t$, and any similarity measure $S$, we compute three scores:
\[
\begin{aligned}
S^{\text{curr}}_{it} \;&=\; S(u_{i,t},\; T_{i,t}) & \text{(both sides at $t$ — the headline)} \\
S^{u}_{it}           \;&=\; S(u_{i,t},\; T_{i,2}) & \text{(focal moves, reference frozen at round 2)} \\
S^{T}_{it}           \;&=\; S(u_{i,2},\; T_{i,t}) & \text{(reference moves, focal frozen at round 2)}
\end{aligned}
\]
The fourth quantity $S(u_{i,2}, T_{i,2})$ is firm-specific and
constant in $t$; under establishment fixed effects it is absorbed
without computation. The three computed scores per measure, together
with their algebraic combinations described in Section 8, are
everything the decomposition needs.

The exercise is run twice. With the connectivity-weighted partner
reference $T_{i,t}$, each focal compares itself against its
firm-specific treated partner profile (sample of 6,943 firm-round
observations across 1,652 establishments after sample restrictions
discussed in Section 9). With the average-treated reference
$\tilde T_t$, the partner side is the universal treated mean and is
the same for all $i$ in any given $t$ (sample of 19,693 firm-round
observations across 4,142 establishments). The two reference choices
answer different versions of the same question, which we exploit in
Section 10.

## 8. Five Outcomes and a Coefficient Identity

The three computed scores give rise to five regression outcomes per
measure, all *linear combinations* of the three scores:
\[
\begin{aligned}
\Delta S_{it}                 \;&=\; S^{\text{curr}}_{it} - S(u_{i,2}, T_{i,2}) & \text{(headline change)} \\
\text{UM}_{it}                \;&=\; S^{u}_{it} - S(u_{i,2}, T_{i,2})             & \text{(\textsc{UntreatedMove})} \\
\text{TM}_{it}                \;&=\; S^{T}_{it} - S(u_{i,2}, T_{i,2})             & \text{(\textsc{TreatedMove})} \\
\text{TA}_{it}                \;&=\; S^{\text{curr}}_{it} - S^{u}_{it}            & \text{(\textsc{TreatedAdditional})} \\
\text{UA}_{it}                \;&=\; S^{\text{curr}}_{it} - S^{T}_{it}            & \text{(\textsc{UntreatedAdditional})}
\end{aligned}
\]
The two main objects are \textsc{UM} and \textsc{TM}. \textsc{UM}
asks how much of the headline change in similarity is delivered by
the focal firm moving toward a *fixed* pre-reform partner anchor.
\textsc{TM} asks how much is delivered by the *partner reference*
moving toward a *fixed* pre-reform focal anchor. The two
\textsc{Additional} terms close two ordered decompositions
\[
    \Delta S = \text{UM} + \text{TA} = \text{TM} + \text{UA}
\]
and capture, in each case, the portion of the headline that is not
delivered by motion of one side alone toward the other side's
pre-reform anchor — i.e. the joint or cross-like component.

**The coefficient identity.** All five outcomes are estimated against
the same DiD specification — identical sample, identical firm fixed
effects, identical period-interacted industry, microregion,
mode-month, and pre-treatment quartile fixed effects — exactly as in
the headline regression of Section 4. Because OLS is linear in the
dependent variable, and because the five outcomes are linear
combinations of one another given $u_{i,2}$ and $T_{i,2}$, the
estimated coefficients on $\text{conn}_i \times \text{post}_t$ satisfy
\[
    \hat\beta_{\Delta S} \;=\; \hat\beta_{\text{UM}} + \hat\beta_{\text{TA}}
                          \;=\; \hat\beta_{\text{TM}} + \hat\beta_{\text{UA}}
\]
*exactly*, to machine precision. We verify this in practice: in both
reference exercises, the largest residual across the four similarity
measures is at the rounding floor of our `%9.4f` CSV write-out
($\le 10^{-4}$), with the underlying numerical residuals at $10^{-12}$
or below. The identity is reported alongside the coefficient table in
the appendix (Table \ref{tab:decomp_full}).

**A subtle implementation point.** For the coefficient identity to
hold, the FE absorb list must be identical across the five
regressions. The headline DiD includes a pre-treatment quartile bin
on the outcome itself (`outcome_pre4`), which is naturally outcome-
specific. We instead bin only the headline outcome $\Delta S$ and use
that single bin (`delta_<measure>_pre4`) as the absorbing FE for all
five outcomes of measure $S$. Using outcome-specific bins breaks the
identity by $\sim 10^{-3}$ — small enough that it would be easy to
overlook and easy to mistake for true heterogeneity. The common-bin
construction makes the identity exact.

## 9. Anchor Choice and Sample

The anchor is the focal firm's round-2 contract and the partner
reference's round-2 vector, $u_{i,2}$ and $T_{i,2}$, evaluated within
the same firm and partner set. Round 2 is the last pre-reform CBA in
the panel and is the omitted category of the event-study
specification; using it as the anchor keeps the decomposition aligned
with the timing convention of the headline DiD.

A two-round average $(u_{i,1} + u_{i,2})/2$ would be a natural
alternative — symmetric across the pre-window pooled by the DiD,
and less sensitive to round-2 idiosyncrasy. We did experiment with
that anchor in an earlier bilinear version of this exercise.
For the present ordered decomposition we keep the round-2 anchor for
three reasons. First, round 2 is already the event-study omitted
category, so the decomposition's pre-trend (which is mechanically
zero at $t = 2$ by construction of each outcome) lines up with the
event study's reference period without further bookkeeping. Second,
the round-2 anchor is well-defined for every firm with a CBA in
round 2, which is exactly the sample restriction the headline already
imposes. Third, the decomposition's economic statement — "would the
focal have caught up to the partner *as it was* before the reform?"
— is sharper when the anchor is a single observed contract, not an
average of two.

The sample restriction in the weighted-reference exercise is
inherited from the partner-anchored term: we need $T_{i,2}$ to exist,
which means the focal must have at least one treated worker-flow
partner with a CBA in round 2 (1,652 establishments). In the average-
reference exercise, the anchor is well-defined for every untreated
firm with $u_{i,2}$, giving 4,142 establishments.

## 10. Decomposition Results

We report two body tables (one per reference choice) and one appendix
table; the latter reports the full five-outcome breakdown plus the
identity residuals. The structure mirrors the headline similarity
table (Section 5): four columns (cosine, total variation, Bray-Curtis,
Ruzicka), two panels.

**Connectivity-weighted partner reference (Table
\ref{tab:decomp_weighted})**. Panel A reports
\textsc{UntreatedMove} — the focal moving toward the partner's
round-2 contract. Panel B reports \textsc{TreatedMove} — the partner
reference moving toward the focal's round-2 contract. The pattern
across the four measures is uniform: neither object is large or
significant.
\[
\begin{array}{lcccc}
\multicolumn{1}{c}{}            & \text{Cosine} & \text{Total var.} & \text{Bray-Curtis} & \text{Ruzicka} \\
\hat\beta_{\Delta S}            & 0.0133^{***} & 0.0102^{***} & 0.0083^{***} & 0.0062^{**} \\
\hat\beta_{\text{UM}}           & -0.0000 & -0.0015 & -0.0012 & -0.0032 \\
\hat\beta_{\text{TM}}           & \phantom{-}0.0037 & \phantom{-}0.0022 & \phantom{-}0.0011 & -0.0007
\end{array}
\]
The remainder of the headline — by construction
$\hat\beta_{\Delta S} - \hat\beta_{\text{UM}} = \hat\beta_{\text{TA}}$
on one side, and $\hat\beta_{\Delta S} - \hat\beta_{\text{TM}} =
\hat\beta_{\text{UA}}$ on the other — is the joint/cross piece. In
cosine, for instance, $\hat\beta_{\text{TA}} = 0.0133$ and
$\hat\beta_{\text{UA}} = 0.0096$, both materially equal to
$\hat\beta_{\Delta S}$ itself: the cross piece carries essentially
the entire spillover under either ordering. The pattern is the same
across all four measures (Table \ref{tab:decomp_full}, Panels TA and
UA). Standard errors of the individual decomposition terms are
reported in the same table.

The reading is clean. When the partner reference is firm-specific,
freezing it at its round-2 value leaves no detectable movement of the
focal toward it; freezing the focal at its round-2 value leaves no
detectable movement of the partner toward it; the convergence in
$\Delta S$ comes entirely from the joint shift. This is the spillover
sample's version of joint motion: each focal and its specific
partners co-evolve, but neither is closing in on the other's
pre-reform contract.

**Average-treated reference (Table \ref{tab:decomp_avg})**. With
$\tilde T_t$, the pattern reverses sharply. \textsc{UntreatedMove}
now equals the headline almost in full:
\[
\begin{array}{lcccc}
\multicolumn{1}{c}{}            & \text{Cosine} & \text{Total var.} & \text{Bray-Curtis} & \text{Ruzicka} \\
\hat\beta_{\Delta S}            & 0.0030^{***} & 0.0019^{**} & 0.0019^{**} & 0.0012^{**} \\
\hat\beta_{\text{UM}}           & 0.0027^{***} & 0.0018^{**} & 0.0013^{**} & 0.0009^{**} \\
\hat\beta_{\text{TM}}           & 0.0004      & 0.0001       & 0.0003       & 0.0002
\end{array}
\]
The \textsc{TreatedMove} coefficient is, as we anticipated in Section
8, mechanically small under the average reference: $\tilde T_t$ does
not depend on $i$, so the conn $\times$ post coefficient on
$S(u_{i,2}, \tilde T_t)$ can only pick up *coincidental* alignment
between the universal treated drift and the period-2 profiles of
high-connectivity firms. The \textsc{UntreatedMove} coefficient is
not constrained the same way: $S(u_{it}, \tilde T_2)$ varies with $i$
through $u_{it}$, and the regression detects whether high-
connectivity untreated firms drift toward the universal pre-reform
treated profile.

**Reading the two tables together.** The contrast between the two
reference exercises is the most informative result of Part II.
Untreated firms *do* move toward a pre-reform treated content
profile — specifically, the universal one $\tilde T_2$. They do *not*
move toward their firm-specific partner profile $T_{i,2}$. The
two findings are not in tension if the destination clause region
post-reform is something close to the *common* pre-reform treated
content: the centroid of all treated CBAs. Each focal firm's
particular partner profile $T_{i,2}$ sits in a more idiosyncratic
location in clause space, often closer to the focal's own pre-reform
contract than the universal centroid is, so the focal's drift toward
$T_{i,2}$ has less room to move and frequently moves *with* $T_{i,t}$
rather than toward $T_{i,2}$.

This reading is also what the bilinear robustness check (appendix)
produces: in $u_t \cdot T_t$ and its share-normalized counterpart,
the cross piece $\Delta u_t \cdot \Delta T_t$ carries the bulk of the
headline coefficient, with the single-side anchored pieces small or
weakly negative. The ordered decomposition above tells the same story
in the four similarity measures the reader already understands. The
appendix shows the algebra is robust to a non-standard bilinear
outcome; the body tables show the conclusion does not depend on it.

**Pre-trends and event-study evidence.** Pre-trend placebos on the
five outcomes are reported in the appendix table; they are
small and individually insignificant across the four measures in
both reference exercises, with the round-2 anchor mechanically
forcing the pre-trend at $t = 2$ to zero for \textsc{UM} and
\textsc{TM}. Period-specific event-study coefficients are written to
`results_es_cba_similarity_decomp.csv` and its avg-reference twin,
and trace out the same gradual onset (round 4 and later) documented
in the headline event study, with the cross-like components rising
post-round-3 in lockstep with $\Delta S$ and the single-side
anchored components remaining flat around zero. Plots are
auxiliary to the tables and not reported in the body.

# Part III — Discussion and Mechanisms

## 11. What the Pattern Implies

A natural intuition is that two vectors becoming more similar over
time requires at least one of them to move toward where the other one
was. This is correct in two dimensions, where convergence between
unit vectors can only be achieved by rotation toward the other's
prior position. In $\mathbb{R}^{139}$ — the clause vector space — the
intuition fails. In high dimensions, two vectors can converge by both
rotating toward a *third* direction. If both focal and partner shift
weight toward a previously low-weight subset of clauses, with the
shifts correlated, the angle between them shrinks, their shared mass
concentrates, and their min/max overlap improves — but neither
vector is moving toward the other's pre-reform position. The
decomposition under the weighted partner reference (Table
\ref{tab:decomp_weighted}) documents exactly this geometry: near-zero
\textsc{UntreatedMove}, near-zero \textsc{TreatedMove}, and a large
positive cross-like residual that, under each ordering of the
decomposition, carries essentially the entire $\hat\beta_{\Delta S}$.

The economic content of the geometry is that the diffusion process at
work is *not* "untreated firms copying the older contracts of their
specific treated peers." Copy-the-partner's-past would deliver a
large $\hat\beta_{\text{UM}}$ and a small cross-like residual —
precisely the opposite of what the weighted-reference table shows.

The average-reference table (Table \ref{tab:decomp_avg}) sharpens the
reading. There, $\hat\beta_{\text{UM}} \approx \hat\beta_{\Delta S}$:
the focal firm *is* drifting toward a pre-reform treated content
profile — but the relevant pre-reform profile is the *universal*
treated mean $\tilde T_2$, not the focal's specific connectivity-
weighted partner profile $T_{i,2}$. The reform appears to have
selected a new region of clause space — clauses whose post-reform
enforceability under ultractivity makes them newly worth negotiating
hard for, or clauses whose pre-reform disputability rendered them
previously unsalient — and that region is well-approximated by where
the *average* treated CBA already sat pre-reform. Each focal's own
worker-flow partners, however, often sit far from this universal
treated centroid: they had their own idiosyncratic mix of clauses,
and the destination region is not where any one of them sat
individually. The convergence with each specific partner is therefore
not delivered by the focal closing the gap to the partner's
pre-reform contract, but by the focal *and* the partner co-drifting
into the universal treated region together.

## 12. Reconciling With the Rest of the Paper

This finding sits beside two facts already documented in the paper:
spillover firms experience wage gains but no change in CBA clause
*counts*. The clause-count null in Section 5.2 says that connected
untreated firms did not negotiate *more* clauses post-reform; the
similarity result says that they did renegotiate the existing clauses
*toward different content*. The two facts are not in conflict but are
*complementary*: the spillover into bargained provisions operates on
the composition margin, not on the quantity margin. A CBA at a
spillover firm post-reform has roughly the same number of clauses as
before, but the clauses sit in a different region of the 139-dimensional
clause space — closer to the region treated firms have also moved
into.

The decomposition further refines the wage versus amenity reading the
paper draws in §5.2. There, the conclusion is that "competitive
pressure from improved outside options manifested in wages rather than
in collectively-bargained provisions." That statement should be
interpreted as referring to the *count* margin, not the *content*
margin. On wages and on the composition of CBAs, both margins respond;
on the count of negotiated clauses, only the directly treated firms
respond. The mechanism for the wage spillover discussed in the paper
— competitive pressure via workers' improved outside options — does
not naturally predict the composition shift on its own, because the
content of the CBA at the spillover firm is not what its outside-
option-using workers see at the partner firm; the worker only sees
the partner's wage and (perhaps) the partner's amenities, not the
clause text. Some other channel must therefore be at work for the
composition shift.

## 13. Candidate Mechanisms

The decomposition narrows the space of candidate mechanisms. Any
mechanism consistent with the joint-motion pattern must satisfy two
properties: it must be mediated by worker-flow connectivity, and it
must produce a destination clause region that is novel rather than a
pre-reform template. Five candidates plausibly satisfy both. We list
them with the empirical handle each one offers.

**Union template updating.** The union representing treated firms
updates its bargaining template in response to ultractivity — clauses
become more valuable to negotiate hard for once enforceability is
guaranteed. Untreated firms connected via worker flows often share or
sit adjacent to the same unions (91\% of untreated establishments
share a union with at least one directly treated firm in our sample),
and therefore absorb the updated template through their own
representation. The paper's Section 5.3 already shows that adding
union $\times$ period fixed effects attenuates but does not eliminate
the headline spillover, and the same attenuation is visible across
the decomposition: under union FE the headline $\hat\beta_{\Delta S}$
shrinks and so does the joint piece (\textsc{TreatedAdditional},
\textsc{UntreatedAdditional}) that carries the bulk of the weighted-
reference decomposition. The union channel is therefore consequential
— substantial portions of the joint motion run through unions — but
the surviving joint piece under union FE suggests that at least one
other channel is also operative. The decomposition's Panel B in the
full appendix table (Table \ref{tab:decomp_full}) reports the
union-FE coefficients for all five outcomes; the qualitative pattern
(small \textsc{UM} and \textsc{TM}, larger joint pieces) survives.

**Shared bargaining infrastructure.** Connected firms tend to share
legal advisors, employer associations, and CBA drafting templates.
Súmula 277 changed the legal status of CBA clauses, so these
intermediaries had a strong incentive to update their templates;
firms sharing an advisor inherit the updated template through them.
This channel predicts that the spillover should concentrate among
firms whose CBAs were prepared by the same advisor or employer
association — testable with advisor or association identifiers
extracted from the CBA text, which we do not yet exploit.

**Worker-carried preferences.** Workers move between connected firms
and carry expectations of "what a CBA should contain." Post-reform,
the demanded clause bundle plausibly shifts toward enforceable
protections (severance, leave, profit-sharing), and a worker who has
experienced these provisions at a connected partner pushes for the
same provisions at the next employer. This channel predicts that the
spillover should track recent hires from connected firms more than
the existing workforce, and should be stronger where worker-flow
intensity is high — testable within RAIS by decomposing the focal
firm's connectivity into the flows it sends vs. the flows it receives.

**Imitation under uncertainty.** After a regime change, neither side
has strong priors over what clauses are now optimal to negotiate.
Firms look to worker-flow peers and copy whichever clauses are
spreading locally. Because peer sets overlap across connected firms,
the network converges on a set of locally-popular clauses — popular
because they are being imitated, not because they descend from any
particular pre-reform contract. This channel predicts that the effect
should be stronger in industries with greater clause-practice
heterogeneity ex ante, where the new optimum is less obvious.

**Local labor-market equilibrium.** Connected firms compete for the
same workers, and Súmula 277 enriched workers' outside options at the
treated firms. Untreated firms must match to retain workers; treated
firms must respond to *their* workers' updated outside options. The
market clears at a new clause bundle reflecting post-reform worker
preferences. This is the most direct analog, on the composition
margin, of the wage-spillover mechanism the paper documents. It
predicts that the effect is stronger where labor markets are tighter
and where worker mobility is high — testable with local labor-market
tightness measures and microregion-level mobility data, both of which
the paper already uses in Section 5.3's robustness checks.

These mechanisms are not mutually exclusive, and the data already
discriminate among them in part: the partial union-FE attenuation
implicates the union template channel; the survival of a cross-like
residual after union absorption implicates at least one of the other
four. The natural next step is to construct direct empirical handles
on the remaining channels — advisor identifiers, hire-vs.-incumbent
decompositions, industry-level pre-reform heterogeneity measures, and
local labor-market tightness controls — and re-run the decomposition
with each in turn. We leave this to future work in the project.

## 14. Summary

Across all four similarity measures and both reference choices, more-
connected untreated firms move toward treated firms' CBAs post-reform.
The convergence is robust to the angle-vs.-magnitude axis embedded in
the choice of similarity measure, and it is detected whether the
partner reference is each focal's specific connectivity-weighted
treated profile or the simple unweighted average across all treated
firms. The headline coefficient is therefore not driven by who the
focal firm shares workers with specifically.

An ordered decomposition of the same exercise — computing, for each
focal-period and each similarity measure, $S(u_t, T_t)$,
$S(u_t, T_2)$, and $S(u_2, T_t)$, and assembling them into the five
outcomes $\Delta S$, \textsc{UM}, \textsc{TM}, \textsc{TA},
\textsc{UA} — splits the spillover into "focal moved toward fixed
partner anchor" (\textsc{UM}), "partner moved toward fixed focal
anchor" (\textsc{TM}), and a joint piece (the \textsc{Additional}
terms). The five outcomes admit an exact coefficient identity
$\hat\beta_{\Delta S} = \hat\beta_{\text{UM}} + \hat\beta_{\text{TA}}
= \hat\beta_{\text{TM}} + \hat\beta_{\text{UA}}$ at machine precision,
which both the weighted- and average-reference exercises satisfy.

The two reference choices, read against the same decomposition,
deliver complementary findings. With the firm-specific
connectivity-weighted partner reference (Table
\ref{tab:decomp_weighted}), \textsc{UM} and \textsc{TM} are both
near zero across all four similarity measures and the joint piece
carries essentially the full headline coefficient. With the
average-treated reference (Table \ref{tab:decomp_avg}), \textsc{UM}
recovers nearly the full headline and \textsc{TM} is mechanically
small. Read together, the two tables imply that the destination of
the spillover is well-approximated by the universal pre-reform
treated centroid $\tilde T_2$, not by any focal firm's specific
partner profile $T_{i,2}$. Untreated firms drift toward the
universal centroid; each specific partner co-drifts into the same
region; and the apparent "shared destination" is in fact the
pre-reform treated mean.

Combined with the high-dimensional geometric observation that two
vectors can converge without either passing through the other's
specific past, the natural reading is that the 2012 reform reactivated
a region of clause space already occupied on average by treated firms
— clauses whose post-reform enforceability under ultractivity made
them newly worth negotiating hard for — and that the worker-flow-
connected portion of the labor market drifted into that region
together. This is complementary to, not in conflict with, the paper's
existing finding of no spillover in CBA clause *counts*: the
spillover into negotiated provisions operates on the composition
margin, not on the quantity margin. The mechanisms compatible with
the pattern range from union template updates and shared bargaining
infrastructure to worker-carried preferences, imitation under
uncertainty, and local labor-market equilibrium. The partial
attenuation of the joint pieces under union $\times$ period FE
implicates the union-template channel as substantial but not
exhaustive; pinning down the remainder is the natural next step in
the project.

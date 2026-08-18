#!/usr/bin/env python
"""
Compact dedicated table for the LOG WAGE spillover under the recentered
instrument, mirroring the format of appendix Table A2 (tab:rob_logwages): each
cell is a coefficient with its clustered standard error beneath, and the panel
closes with the number of establishments and observations.

Two columns for the spillover on log wages:
  (1) Baseline                — Post x Connectivity, no counterfactual
  (2) Recentered (Ind x Month)— adds Post x expected connectivity, where the
                                expectation is over 1,000 reshuffles of the
                                treated set within industry x negotiation-month
                                cells (Borusyak and Hull, 2023)

Rows: Post x Connectivity (true), Post x Expected connectivity (the added
recentered control), Pre-trend placebo on connectivity, Pre-trend placebo on
expected connectivity, Establishments, Observations. Control connectivity is
NOT shown. This lives in its own table rather than as a column of A2, because
A2's columns suppress their controls' coefficients whereas the recentering's
payload is precisely the expected-connectivity coefficient.

Reads Tables/rand_inference/horserace_recentered.csv (baseline + ind_month).
Writes rob_logwages_recentered.tex.
"""
import pandas as pd
from pathlib import Path
from scipy import stats

TAB = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill/Tables/rand_inference")
OUT = TAB / "rob_logwages_recentered.tex"
NEST = 4084  # untreated establishments in the spillover sample (matches Table A2)

hr = pd.read_csv(TAB / "horserace_recentered.csv")


def pick(df, key, col, val):
    r = df[(df.outcome == "lr_remdezr_w") & (df[key] == val) & (df.coef == col)]
    return float(r.b.iloc[0]), float(r.se.iloc[0]), int(r.n.iloc[0])


def stars(b, se):
    p = 2 * (1 - stats.norm.cdf(abs(b / se)))
    return "^{***}" if p < 0.01 else "^{**}" if p < 0.05 else "^{*}" if p < 0.10 else ""


def cell(b, se, star=True):
    s = stars(b, se) if star else ""
    return f"${b:.4f}{s}$", f"$({se:.4f})$"


# column 1: baseline (no counterfactual)
b1, se1, n1 = pick(hr, "scheme", "conn_post", "baseline")
pb1, pse1, _ = pick(hr, "scheme", "conn_pre", "baseline")
# column 2: recentered instrument, industry x month
b2, se2, n2 = pick(hr, "scheme", "conn_post", "ind_month")
g2, gse2, _ = pick(hr, "scheme", "mu_post", "ind_month")
pb2, pse2, _ = pick(hr, "scheme", "conn_pre", "ind_month")

c1b, c1s = cell(b1, se1)
c2b, c2s = cell(b2, se2)
g2b, g2s = cell(g2, gse2)
p1b, p1s = cell(pb1, pse1, star=False)
p2b, p2s = cell(pb2, pse2, star=False)

tex = rf"""\begin{{table}}[H]
\centering
\caption{{Log wage spillover: recentered connectivity}}
\label{{tab:rob_logwages_recentered}}
\footnotesize
\begin{{tabular}}{{lcc}}
\toprule\toprule
 & Baseline & \shortstack{{Recentered\\(Ind.\ $\times$ Month)}} \\
 & (1) & (2) \\
\midrule
Post $\times$ Connectivity             & {c1b} & {c2b} \\
                                       & {c1s} & {c2s} \\[2pt]
Post $\times$ Expected connectivity    & ---   & {g2b} \\
                                       &       & {g2s} \\[4pt]
\quad Pre-trend (placebo)              & {p1b} & {p2b} \\
                                       & {p1s} & {p2s} \\
\midrule
Establishments                         & {NEST:,} & {NEST:,} \\
Observations                           & {n1:,} & {n2:,} \\
\bottomrule\bottomrule
\end{{tabular}}

\begin{{minipage}}{{0.9\linewidth}}
\scriptsize\vspace{{4pt}}
\textit{{Notes:}} Pooled spillover regression of log wages on connectivity to
treated firms $\times$ Post, estimated on untreated establishments. Column~(1) is
the baseline specification. Column~(2) is the recentered instrument of Borusyak
and Hull (2023): it adds \emph{{expected}} connectivity $\times$ Post, where the
expectation is taken over $1{{,}}000$ reshuffles of the treated set within
industry $\times$ negotiation-month cells; a stable connectivity estimate
alongside an expected-connectivity coefficient near zero indicates that the
spillover reflects realized rather than counterfactual exposure to treatment.
The pre-trend row reports the coefficient on connectivity $\times$ Pre from the
$2009$--$2011$ placebo. Both specifications include
establishment fixed effects, industry, microregion and negotiation-month fixed
effects interacted with year, and quartile bins of pre-treatment size,
per-worker flows, and log wages interacted with year. Standard errors clustered
at the establishment level in parentheses. $^{{*}}$ $p<0.10$, $^{{**}}$ $p<0.05$,
$^{{***}}$ $p<0.01$.
\end{{minipage}}
\end{{table}}
"""

OUT.write_text(tex)
print("wrote:", OUT)
print(tex)

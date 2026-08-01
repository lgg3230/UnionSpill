#!/usr/bin/env python3
"""
Build the 8-column "Robustness of Wage Effects" fragment.

Layout
------
  (1) Main            (2) 10 Bins        (3) 20 Bins   (4) Workforce char.
  (5) Linear,  % firms treated           (6) Linear,   % workers treated
  (7) Quartile,% firms treated           (8) Quartile, % workers treated

Columns (5)-(8) are a 2x2 over {control functional form} x {exposure measure}.
EVERY column reports a direct effect in Panel A and a spillover effect in
Panel B -- there are no "---" cells. Columns (5)-(6) keep the local-industry
exposure control linear (as in the original paper table); columns (7)-(8) put
the same control in quartile bins. The contrast is functional form only: both
enter interacted with year fixed effects.

Sources
-------
  cols (1)-(4), both panels : t_rob{suf}.6col.orig.tex   (pristine snapshot of
                              the inlined tex block; never this script's own
                              output, so the generator stays idempotent)
  cols (5)-(8), both panels : results_micro_ind_q{suf}.csv
                              spillover  mif_lin miw_lin mif_q miw_q
                              direct     dir_mif_lin dir_miw_lin
                                         dir_mif_q dir_miw_q

Normalization: mi_exp_f_n / mi_exp_w_n are scaled by the p90 among SPILLOVER
firms in 2009 in both panels (decision 2026-07-31), so the direct and spillover
linear coefficients in a column share one scale and their ratio is meaningful.

Every column's spillover/direct ratio divides by the direct estimate from that
same column. No dagger mechanism.

Pre-treatment Mean rows are emitted only when INCLUDE_MEAN=1 (task 6 is still
under review).
"""
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
FRAG = ROOT / "quality_reports/replication/hourly_variant_currentconn/frag"
CSVD = ROOT / "Tables/currentconn_full/robustness"
INCLUDE_MEAN = os.environ.get("INCLUDE_MEAN", "0") == "1"

# column -> (spillover spec, direct spec) for columns 5..8
COLSPECS = [
    ("mif_lin", "dir_mif_lin"),   # (5) linear,   % firms
    ("miw_lin", "dir_miw_lin"),   # (6) linear,   % workers
    ("mif_q",   "dir_mif_q"),     # (7) quartile, % firms
    ("miw_q",   "dir_miw_q"),     # (8) quartile, % workers
]


def load_q(suf):
    out = {}
    for line in (CSVD / f"results_micro_ind_q{suf}.csv").read_text().splitlines()[1:]:
        f = line.split(";")
        if len(f) < 4:
            continue
        out.setdefault(f[0].strip().strip('"'), {})[f[2].strip().strip('"')] = \
            f[3].strip().strip('"').strip()
    return out


def cells(line):
    return [c.strip() for c in re.sub(r"\\\\\s*$", "", line.rstrip()).split("&")]


def parse_orig(suf):
    """columns 1-4 of every labelled row, per panel, from the pristine snapshot."""
    src = (FRAG / f"t_rob{suf}.6col.orig.tex").read_text().splitlines()
    LBL = ("Post $\\times$ Treatment", "Post $\\times$ Connectivity",
           "Observations", "Establishments", "Pre-trend (placebo)")
    keep, panel, prev = {}, None, None
    for ln in src:
        s = ln.strip()
        if s.startswith(r"\multicolumn{7}{l}{\textbf{Panel A:}"):
            panel, prev = "A", None; continue
        if s.startswith(r"\multicolumn{7}{l}{\textbf{Panel B:}"):
            panel, prev = "B", None; continue
        if panel is None:
            continue
        if s.startswith("&") and prev:
            keep[(panel, prev + "_se")] = cells(s)[1:5]
            prev = None
            continue
        for lbl in LBL:
            if s.startswith(lbl + " &"):
                keep[(panel, lbl)] = cells(s)[1:5]
                prev = lbl if "Post" in lbl or "Pre-trend" in lbl else None
                break
    return keep


def num(v):
    """strip stars / LaTeX minus and return float"""
    return float(re.sub(r"[*]", "", v).replace("$-$", "-").replace("{,}", "").strip())


def build(suf):
    q = load_q(suf)
    orig = parse_orig(suf)

    missing = [sp for pair in COLSPECS for sp in pair if sp not in q]
    if missing:
        raise SystemExit(f"missing specs in results_micro_ind_q{suf}.csv: {missing}")

    def k(panel, lbl):
        v = orig.get((panel, lbl))
        if v is None:
            raise SystemExit(f"cannot parse cols 1-4 for {panel}/{lbl}")
        return v

    def thou(spec, rt):
        return q[spec][rt].replace(",", "{,}")

    # ---- ratios: spillover / direct, per column ----------------------------
    ratios = []
    for i in range(4):                                    # cols 1-4
        ratios.append(f"{num(k('B','Post $\\times$ Connectivity')[i]) / num(k('A','Post $\\times$ Treatment')[i]):.2f}")
    for sp, dr in COLSPECS:                               # cols 5-8
        ratios.append(f"{num(q[sp]['main']) / num(q[dr]['main']):.2f}")

    wage = "log hourly wage" if suf == "_hw" else "log wage"
    cap = ("Robustness of Wage Effects --- \\textbf{Log Hourly Wages}"
           if suf == "_hw" else "Robustness of Wage Effects")

    L, A = [], None
    A = L.append
    A(r"\begin{table}[H]")
    A(r"\centering")
    A(r"\caption{" + cap + r"}")
    # nine columns overflow \textwidth at \footnotesize with default \tabcolsep
    A(r"\scriptsize")
    A(r"\setlength{\tabcolsep}{3pt}")
    A(r"\begin{tabular}{lcccccccc}")
    A(r"\toprule\toprule")
    A(r" & & \multicolumn{2}{c}{Controls: \# Bins} & Controls: & "
      r"\multicolumn{4}{c}{Controls: Local Industry} \\")
    A(r"\cmidrule(lr){3-4} \cmidrule(lr){5-5} \cmidrule(lr){6-9}")
    A(r" & & & & & \multicolumn{2}{c}{Linear} & "
      r"\multicolumn{2}{c}{Quartile bins} \\")
    A(r"\cmidrule(lr){6-7} \cmidrule(lr){8-9}")
    A(r" & \begin{tabular}[c]{@{}c@{}}Main\end{tabular}"
      r" & \begin{tabular}[c]{@{}c@{}}10 Bins\end{tabular}"
      r" & \begin{tabular}[c]{@{}c@{}}20 Bins\end{tabular}"
      r" & \begin{tabular}[c]{@{}c@{}}Workforce\\Characteristics\end{tabular}"
      r" & \begin{tabular}[c]{@{}c@{}}\% Firms\\Treated\end{tabular}"
      r" & \begin{tabular}[c]{@{}c@{}}\% Workers\\Treated\end{tabular}"
      r" & \begin{tabular}[c]{@{}c@{}}\% Firms\\Treated\end{tabular}"
      r" & \begin{tabular}[c]{@{}c@{}}\% Workers\\Treated\end{tabular} \\")
    A(r" & (1) & (2) & (3) & (4) & (5) & (6) & (7) & (8) \\")
    A(r"\midrule")

    def row(label, first4, last4):
        A(label + " & " + " & ".join(list(first4) + list(last4)) + r"\\")

    # ---------------- Panel A -------------------------------------------------
    A(r"\multicolumn{9}{l}{\textbf{Panel A:} Direct Effects } \\")
    row(r"Post $\times$ Treatment", k("A", "Post $\\times$ Treatment"),
        [q[d]["main"] for _, d in COLSPECS])
    row(" ", k("A", "Post $\\times$ Treatment_se"),
        [f"({q[d]['main_se']})" for _, d in COLSPECS])
    A(r" &  &  &  &  &  &  &  & \\")
    if INCLUDE_MEAN:
        row("Mean", [q["dir_base"]["mean_pre"]] * 4,
            [q[d]["mean_pre"] for _, d in COLSPECS])
    row("Observations", k("A", "Observations"), [thou(d, "n_obs") for _, d in COLSPECS])
    row("Establishments", k("A", "Establishments"), [thou(d, "n_estab") for _, d in COLSPECS])
    A(r"\midrule")
    row(r"Pre-trend (placebo)", k("A", "Pre-trend (placebo)"),
        [q[d]["pre"] for _, d in COLSPECS])
    row(" ", k("A", "Pre-trend (placebo)_se"),
        [f"({q[d]['pre_se']})" for _, d in COLSPECS])
    A(r" &  &  &  &  &  &  &  & \\")
    A(r" \midrule")

    # ---------------- Panel B -------------------------------------------------
    A(r"\multicolumn{9}{l}{\textbf{Panel B:} Spillover Effects} \\")
    row(r"Post $\times$ Connectivity", k("B", "Post $\\times$ Connectivity"),
        [q[s]["main"] for s, _ in COLSPECS])
    row(" ", k("B", "Post $\\times$ Connectivity_se"),
        [f"({q[s]['main_se']})" for s, _ in COLSPECS])
    A(r" &  &  &  &  &  &  &  & \\")
    A(r"Spillover / direct effect & " + " & ".join(ratios) + r"\\")
    A(r" &  &  &  &  &  &  &  & \\")
    if INCLUDE_MEAN:
        row("Mean", [q["mif_lin"]["mean_pre"]] * 4,
            [q[s]["mean_pre"] for s, _ in COLSPECS])
    row("Observations", k("B", "Observations"), [thou(s, "n_obs") for s, _ in COLSPECS])
    row("Establishments", k("B", "Establishments"), [thou(s, "n_estab") for s, _ in COLSPECS])
    A(r"\midrule")
    row(r"Pre-trend (placebo)", k("B", "Pre-trend (placebo)"),
        [q[s]["pre"] for s, _ in COLSPECS])
    row(" ", k("B", "Pre-trend (placebo)_se"),
        [f"({q[s]['pre_se']})" for s, _ in COLSPECS])
    A(r"\bottomrule\bottomrule")
    A(r"\end{tabular}")
    A(r"\begin{minipage}{\linewidth}")
    A(r"    \scriptsize\vspace{4pt}")
    A(r"    \textit{Notes:} This table summarizes the robustness of the "
      r"current-connectivity " + wage + r" results across alternative "
      r"specifications. Panel~A reports direct effects, comparing directly "
      r"treated establishments to untreated establishments with zero pre-reform "
      r"connectivity; Panel~B reports spillover effects on the full sample of "
      r"untreated establishments. Column~(1) is the baseline specification with "
      r"quartile-bin controls. Columns~(2)--(3) replace quartile bins with "
      r"$N$-bin controls. Column~(4) adds workforce-characteristic controls. "
      r"Columns~(5)--(8) add controls for local treatment exposure within each "
      r"establishment's industry $\times$ microregion cell, measured as the "
      r"share of directly treated establishments (columns 5 and 7) or the share "
      r"of employment in directly treated establishments (columns 6 and 8). "
      r"Columns~(5)--(6) enter these controls linearly and columns~(7)--(8) as "
      r"quartile bins cut on the 2009 value; both are interacted with year fixed "
      r"effects, so the columns differ only in functional form. Local exposure "
      r"is normalized to its 90th percentile among untreated (spillover-sample) "
      r"establishments in both panels, so the direct and spillover coefficients "
      r"in a column share one scale. The spillover/direct ratio divides the "
      r"Panel~B estimate by the Panel~A estimate from the same column. "
      + (r"Mean is the pre-treatment (2009--2011) average of the dependent "
         r"variable across establishments in each panel's estimation sample, "
         r"pooling treated and control establishments. " if INCLUDE_MEAN else "")
      + r"Standard errors clustered at the establishment level in parentheses. "
        r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10.")
    A(r"\end{minipage}")
    A(r"\end{table}")

    (FRAG / f"t_rob{suf}.tex").write_text("\n".join(L) + "\n")
    print(f"wrote t_rob{suf}.tex  ratios={ratios}")


for suf in ("", "_hw"):
    build(suf)

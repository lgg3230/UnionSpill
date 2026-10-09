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

Sources (estimator CSVs only; since 2026-10-09 no frozen .tex snapshot)
-------
  col (1) Main        : Tables/pct_tfpw_cc/results_{direct_panelA,spill}_tfpw_07_11_pct.csv
                        (3011 -> 3012)
  cols (2)-(3) Bins   : Tables/currentconn_full/robustness/results_{direct_panelA,spill}_robustness_bins.csv,
                        specs tfpw_07_11_pct_bins10 / _bins20 (3051 -> 3052)
  col (4) Workforce   : Tables/currentconn_full/robustness/results_demo_controls{suf}.csv,
                        col 2 = demographic quartile bins (3181 -> 3182)
  cols (5)-(8)        : results_micro_ind_q{suf}.csv (3061 -> 3062)
                        spillover  mif_lin miw_lin mif_q miw_q
                        direct     dir_mif_lin dir_miw_lin
                                   dir_mif_q dir_miw_q
  Panel A = direct_A (zero-connectivity controls); Panel B = spill.
  A suffix ("" monthly, "_hw" hourly) is built only if all its CSVs exist.

Normalization: mi_exp_f_n / mi_exp_w_n are scaled by the p90 among SPILLOVER
firms in 2009 in both panels (decision 2026-07-31), so the direct and spillover
linear coefficients in a column share one scale and their ratio is meaningful.

Every column's spillover/direct ratio divides by the direct estimate from that
same column. No dagger mechanism.

Pre-treatment mean rows are emitted by default (plan 2026-08-01); set
INCLUDE_MEAN=0 to suppress them.
"""
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent.parent
FRAG = ROOT / "quality_reports/replication/hourly_variant_currentconn/frag"
CSVD = ROOT / "Tables/currentconn_full/robustness"
MAIN = ROOT / "Tables/pct_tfpw_cc"
def fmt_mean(raw):
    """CSV keeps 4 decimals; the table shows 3 (decision 2026-08-02)."""
    val = float(str(raw).strip())
    return ("$-$" if val < 0 else "") + f"{abs(val):.3f}"


INCLUDE_MEAN = os.environ.get("INCLUDE_MEAN", "1") == "1"

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


def read_rows(path):
    """semicolon CSV -> list of field lists, quotes and padding stripped"""
    rows = []
    for line in path.read_text().splitlines()[1:]:
        f = [x.strip().strip('"').strip() for x in line.split(";")]
        if len(f) >= 4:
            rows.append(f)
    return rows


ROWS = ("main", "main_se", "pre", "pre_se", "n_obs", "n_estab", "mean_pre")


def first4_sources(suf):
    """paths for columns 1-4; None if any is missing"""
    paths = [MAIN / "results_direct_panelA_tfpw_07_11_pct.csv",
             MAIN / "results_spill_tfpw_07_11_pct.csv",
             CSVD / "results_direct_panelA_robustness_bins.csv",
             CSVD / "results_spill_robustness_bins.csv",
             CSVD / f"results_demo_controls{suf}.csv",
             CSVD / f"results_micro_ind_q{suf}.csv"]
    return paths if all(p.exists() for p in paths) else None


def load_first4(suf):
    """{(panel, col): {row_type: value}} for columns 1-4, panel in A/B"""
    y = "lr_remdezr_h_w" if suf == "_hw" else "lr_remdezr_w"
    out = {}
    for panel, sec, main_f, bins_f in (
            ("A", "direct_A", "results_direct_panelA_tfpw_07_11_pct.csv",
             "results_direct_panelA_robustness_bins.csv"),
            ("B", "spill", "results_spill_tfpw_07_11_pct.csv",
             "results_spill_robustness_bins.csv")):
        for spec, _sec, outc, rt, val in read_rows(MAIN / main_f):
            if spec == "tfpw_07_11_pct" and _sec == sec and outc == y:
                out.setdefault((panel, 1), {})[rt] = val
        for spec, _sec, outc, rt, val in read_rows(CSVD / bins_f):
            for col, tag in ((2, "bins10"), (3, "bins20")):
                if spec == f"tfpw_07_11_pct_{tag}" and _sec == sec and outc == y:
                    out.setdefault((panel, col), {})[rt] = val
        for _sec, outc, col, rt, val in read_rows(CSVD / f"results_demo_controls{suf}.csv"):
            if _sec == sec and outc == y and col == "2":
                out.setdefault((panel, 4), {})[rt] = val
    for panel in "AB":
        for col in (1, 2, 3, 4):
            miss = [r for r in ROWS if r not in out.get((panel, col), {})]
            if miss:
                raise SystemExit(f"t_rob{suf}: panel {panel} col {col} missing {miss}")
    return out


def num(v):
    """strip stars / LaTeX minus and return float"""
    return float(re.sub(r"[*]", "", v).replace("$-$", "-").replace("{,}", "").strip())


def build(suf):
    if first4_sources(suf) is None:
        print(f"skip t_rob{suf}.tex: estimator CSVs for this outcome not all present")
        return
    q = load_q(suf)
    c4 = load_first4(suf)

    missing = [sp for pair in COLSPECS for sp in pair if sp not in q]
    if missing:
        raise SystemExit(f"missing specs in results_micro_ind_q{suf}.csv: {missing}")

    def k(panel, rt, wrap=None):
        """columns 1-4 of one row type, formatted like columns 5-8"""
        vals = [c4[(panel, c)][rt] for c in (1, 2, 3, 4)]
        if rt in ("n_obs", "n_estab"):
            return [v.replace(",", "{,}") for v in vals]
        if rt == "mean_pre":
            return [fmt_mean(v) for v in vals]
        return [f"({v})" for v in vals] if wrap else vals

    def thou(spec, rt):
        return q[spec][rt].replace(",", "{,}")

    # ---- ratios: spillover / direct, per column ----------------------------
    ratios = []
    for i in range(4):                                    # cols 1-4
        ratios.append(f"{num(k('B', 'main')[i]) / num(k('A', 'main')[i]):.2f}")
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
    row(r"Post $\times$ Treatment", k("A", "main"),
        [q[d]["main"] for _, d in COLSPECS])
    row(" ", k("A", "main_se", wrap=True),
        [f"({q[d]['main_se']})" for _, d in COLSPECS])
    A(r" &  &  &  &  &  &  &  & \\")
    if INCLUDE_MEAN:
        row("Pre-treatment mean", k("A", "mean_pre"),
            [fmt_mean(q[d]["mean_pre"]) for _, d in COLSPECS])
    row("Observations", k("A", "n_obs"), [thou(d, "n_obs") for _, d in COLSPECS])
    row("Establishments", k("A", "n_estab"), [thou(d, "n_estab") for _, d in COLSPECS])
    A(r"\midrule")
    row(r"Pre-trend (placebo)", k("A", "pre"),
        [q[d]["pre"] for _, d in COLSPECS])
    row(" ", k("A", "pre_se", wrap=True),
        [f"({q[d]['pre_se']})" for _, d in COLSPECS])
    A(r" &  &  &  &  &  &  &  & \\")
    A(r" \midrule")

    # ---------------- Panel B -------------------------------------------------
    A(r"\multicolumn{9}{l}{\textbf{Panel B:} Spillover Effects} \\")
    row(r"Post $\times$ Connectivity", k("B", "main"),
        [q[s]["main"] for s, _ in COLSPECS])
    row(" ", k("B", "main_se", wrap=True),
        [f"({q[s]['main_se']})" for s, _ in COLSPECS])
    A(r" &  &  &  &  &  &  &  & \\")
    A(r"Spillover / direct effect & " + " & ".join(ratios) + r"\\")
    A(r" &  &  &  &  &  &  &  & \\")
    if INCLUDE_MEAN:
        row("Pre-treatment mean", k("B", "mean_pre"),
            [fmt_mean(q[s]["mean_pre"]) for s, _ in COLSPECS])
    row("Observations", k("B", "n_obs"), [thou(s, "n_obs") for s, _ in COLSPECS])
    row("Establishments", k("B", "n_estab"), [thou(s, "n_estab") for s, _ in COLSPECS])
    A(r"\midrule")
    row(r"Pre-trend (placebo)", k("B", "pre"),
        [q[s]["pre"] for s, _ in COLSPECS])
    row(" ", k("B", "pre_se", wrap=True),
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
      + (r"Pre-treatment mean is the mean of the dependent variable over "
         r"2009--2011 in the estimation sample of the corresponding column. " if INCLUDE_MEAN else "")
      + r"Standard errors clustered at the establishment level in parentheses. "
        r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10.")
    A(r"\end{minipage}")
    A(r"\end{table}")

    (FRAG / f"t_rob{suf}.tex").write_text("\n".join(L) + "\n")
    print(f"wrote t_rob{suf}.tex  ratios={ratios}")


for suf in ("", "_hw"):
    build(suf)

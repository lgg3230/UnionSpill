"""
generate_cba_similarity_multi_ref_latex.py

Reads results_spill_cba_similarity_multi_ref.csv and produces TWO LaTeX tables:
  Tables/cba_similarity/cba_similarity_multi_ref_cosine_table.tex
  Tables/cba_similarity/cba_similarity_multi_ref_ruzicka_table.tex

Each table has 5 columns — one per reference CBA:
  (1) Treated, time-varying        (Ref A — treat_t)
  (2) Treated, fixed at p2         (Ref B — treat_p2)
  (3) Treated, mean of p1, p2      (Ref C — treat_p12)
  (4) Self at p2                   (Ref D — self_p2)
  (5) Self, mean of p1, p2         (Ref E — self_p12)
"""

import pandas as pd
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "cba_similarity"
csv_path   = tables_dir / "results_spill_cba_similarity_multi_ref.csv"

REF_SUFFIXES = ["treat_t", "treat_p2", "treat_p12", "self_p2", "self_p12"]
REF_HEADERS  = [
    r"\shortstack{Treated\\(time-varying)}",
    r"\shortstack{Treated\\(fixed at $p_2$)}",
    r"\shortstack{Treated\\(mean of $p_1, p_2$)}",
    r"\shortstack{Self\\(at $p_2$)}",
    r"\shortstack{Self\\(mean of $p_1, p_2$)}",
]

MEASURES = [("cosine", "Cosine"), ("ruzicka", "Ruzicka")]

# ── Load CSV ──────────────────────────────────────────────────────────────────
df = pd.read_csv(csv_path, sep=";", header=0,
                 names=["spec", "section", "outcome", "row_type", "value"])
df["value"] = df["value"].astype(str).str.strip().str.strip('"')


def get(outcome: str, row_type: str, default: str = "") -> str:
    rows = df[(df.outcome == outcome) & (df.row_type == row_type)]
    return rows["value"].iloc[0] if len(rows) > 0 else default


def fmt_coef(val):
    try:
        s = str(val).strip()
        s_no_stars = s.rstrip("*")
        v = float(s_no_stars)
        stars = s[len(s_no_stars):]
        return f"{v:.4f}{stars}"
    except Exception:
        return str(val)


def fmt_se(val):
    try:
        return f"({float(val):.4f})"
    except Exception:
        return f"({val})"


def fmt_n(val):
    try:
        return f"{int(float(val)):,}"
    except Exception:
        return str(val)


def fmt_pval(val):
    try:
        return f"{float(val):.3f}"
    except Exception:
        return str(val)


def fmt_mean(val):
    try:
        return f"{float(val):.4f}"
    except Exception:
        return str(val)


def build_table(measure_key: str, measure_label: str) -> str:
    outcomes = [f"{measure_key}_{s}" for s in REF_SUFFIXES]

    rows = dict(
        main    = [fmt_coef(get(o, "main"))          for o in outcomes],
        main_se = [fmt_se(  get(o, "main_se"))       for o in outcomes],
        pre     = [fmt_coef(get(o, "pre"))           for o in outcomes],
        pre_se  = [fmt_se(  get(o, "pre_se"))        for o in outcomes],
        n       = [fmt_n(   get(o, "n_obs"))         for o in outcomes],
        nest    = [fmt_n(   get(o, "n_estab"))       for o in outcomes],
        pval    = [fmt_pval(get(o, "pre_pval"))      for o in outcomes],
        bmean   = [fmt_mean(get(o, "baseline_mean")) for o in outcomes],
    )

    ncols    = len(outcomes) + 1
    col_spec = "l" + "c" * len(outcomes)
    col_num  = " & " + " & ".join([f"({i+1})" for i in range(len(outcomes))]) + r" \\"
    col_lbl  = " & " + " & ".join(REF_HEADERS) + r" \\"

    def row(label, cells):
        return label + " & " + " & ".join(cells) + r" \\"

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{measure_label} Similarity to Each Reference CBA: Spillover from Connectivity}}",
        rf"\label{{tab:cba_sim_multi_ref_{measure_key}}}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{6pt}",
        r"\begin{tabular}{" + col_spec + r"}",
        r"\hline\hline",
        col_num,
        col_lbl,
        r"\hline",
        rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Post-treatment}}}} \\",
        row(r"Connectivity $\times$ Post", rows["main"]),
        row("",                            rows["main_se"]),
        rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Pre-treatment placebo}}}} \\",
        row(r"Connectivity $\times$ Pre",  rows["pre"]),
        row("",                            rows["pre_se"]),
        r"\hline",
        row("Baseline mean ($p_2$)",       rows["bmean"]),
        row("Observations",                rows["n"]),
        row("Establishments",              rows["nest"]),
        row("Pre-trend $p$-value",         rows["pval"]),
        r"\hline\hline",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\smallskip",
        (rf"\scriptsize\textit{{Notes:}} This table reports spillover-effect estimates of "
         rf"{measure_label.lower()} similarity between an untreated firm's CBA at the row "
         r"period and one of five reference CBAs. Columns differ only in how the "
         r"reference CBA is constructed: (1) flow-weighted average of connected "
         r"treated firms' CBAs at the same period; (2) the same flow-weighted "
         r"average but fixed at the last pre-treatment period $p_2$; (3) the "
         r"equal-weighted mean of the (1)-style references at $p_1$ and $p_2$; "
         r"(4) the focal firm's own CBA at $p_2$; (5) the equal-weighted mean of "
         r"the focal firm's own CBAs at $p_1$ and $p_2$. Connectivity is scaled "
         r"to 1 at the 90th percentile of the spillover sample. All specifications "
         r"include establishment, industry $\times$ period, mode-month $\times$ period, "
         r"and microregion $\times$ period fixed effects, with pre-treatment bins "
         r"of the outcome, log employment, and total flows absorbed. Standard "
         r"errors clustered at the establishment level. "
         r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


for key, label in MEASURES:
    out_path = tables_dir / f"cba_similarity_multi_ref_{key}_table.tex"
    out_path.write_text(build_table(key, label))
    print(f"LaTeX table written to {out_path}")

"""
Assemble disentangling table for the occ4 layer (occupation 4-bin, CBO 2002).

Reads results_disentangle_occ4_layer_spill.csv produced by 11c_disentangling_occ4.do
and outputs:
  Tables/layer_connectivity/table_disentangle_occ4.tex
  Tables/layer_connectivity/table_disentangle_occ4.csv

Layout (transposed relative to 12_make_table_disentangle.py):
  Panels  = regressors  (4 panels: Managers, High-skill, Bur. lower, Low-skill)
  Columns = outcome layer × {wage, emp} + firm-level × {wage, emp}
          = 4×2 + 2 = 10 data columns

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/12d_make_table_disentangle_occ4.py
"""

from pathlib import Path
import pandas as pd

PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"

LAYER     = "occ4"
LAYER_CSV = TABLES / f"results_disentangle_{LAYER}_layer_spill.csv"
SECTION   = "layer_firm_year"   # within-firm FE (main spec)

LAYER_VALS = ["1_mgr", "23_high", "4_bur", "5p_low"]

LV_LABELS = {
    "1_mgr":    "Managers",
    "23_high":  "High-skill",
    "4_bur":    "Bur. lower",
    "5p_low":   "Low-skill",
}

# (short label, layer-outcome prefix, firm-outcome key)
# Hourly wage excluded to keep the table manageable with 4 layers
OUTCOMES = [
    ("Log Dec. wage",   "lr_remdezr_layer", "lr_remdezr_w"),
    ("Log employment",  "l_layer_emp",       "l_firm_emp"),
]

STAT_ROWS = [
    ("n_obs",      "Observations",            False),
    ("n_firms",    "Firms",                   False),
    ("pre_ftest",  r"Pre-trend F-test $p$-value", True),
]


# ── CSV loader ─────────────────────────────────────────────────────────────────
def load_csv(path: Path) -> dict:
    d: dict = {}
    with open(path) as f:
        for i, line in enumerate(f):
            line = line.rstrip("\n")
            if i == 0:
                continue
            parts = [p.strip('"') for p in line.split(";")]
            if len(parts) >= 5:
                section, outcome, row_type, value = parts[1], parts[2], parts[3], parts[4]
                d[(section, outcome, row_type)] = value
    return d


data = {}
if LAYER_CSV.exists():
    data = load_csv(LAYER_CSV)
else:
    raise SystemExit(f"Missing: {LAYER_CSV}\nRun 11c_disentangling_occ4.do first.")


def get(section, outcome, row_type, default="--"):
    return data.get((section, outcome, row_type), default)

def lget(lv_r, lv_o, out_prefix, rt):
    """Layer-level: outcome = {out_prefix}_{lv_o}, row_type = c_{lv_r}_{rt}."""
    return get(SECTION, f"{out_prefix}_{lv_o}", f"c_{lv_r}_{rt}")

def fget(lv_r, out_firm, rt):
    """Firm-level: outcome = out_firm, row_type = c_{lv_r}_{rt}."""
    return get("firm_firm_year", out_firm, f"c_{lv_r}_{rt}")


# ── Formatting helpers ─────────────────────────────────────────────────────────
def fmt_coef(v: str) -> str:
    return v.strip() if v.strip() not in ("--", "") else "--"

def fmt_se(v: str) -> str:
    s = v.strip()
    if s in ("--", ""):
        return "--"
    try:
        return f"({float(s):.4f})"
    except ValueError:
        return s

def fmt_stat(v: str, is_pval: bool = False) -> str:
    s = v.strip()
    if s in ("--", ""):
        return "---"
    if is_pval:
        try:
            return f"{float(s):.3f}"
        except ValueError:
            return s
    return s


# ── LaTeX builder ──────────────────────────────────────────────────────────────
def build_latex() -> str:
    n_lv      = len(LAYER_VALS)
    n_out     = len(OUTCOMES)
    # Columns: 4 outcome_layers × n_out outcomes + n_out firm-level = n_lv*n_out + n_out
    n_data    = (n_lv + 1) * n_out   # (4+1) × 2 = 10
    ncols     = 1 + n_data

    col_spec  = "l" + "c" * n_data
    lines     = []
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(
        r"\caption{Disentangling layer spillover effects --- "
        r"occupation layers (CBO 2002), within-firm FE}"
    )
    lines.append(r"\label{tab:disentangle_occ4}")
    lines.append(r"\scriptsize")
    lines.append(r"\begin{threeparttable}")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    # ── Header row 1: outcome-layer groups (each spans n_out cols) ─────────────
    h1 = [""]
    for lv_o in LAYER_VALS:
        h1.append(r"\multicolumn{" + str(n_out) + r"}{c}{" + LV_LABELS[lv_o] + r"}")
    h1.append(r"\multicolumn{" + str(n_out) + r"}{c}{Firm-level}")
    lines.append(" & ".join(h1) + r" \\")

    cmi = []
    col = 2
    for _ in range(n_lv + 1):
        cmi.append(f"\\cmidrule(lr){{{col}-{col + n_out - 1}}}")
        col += n_out
    lines.append(" ".join(cmi))

    # ── Header row 2: outcome labels ───────────────────────────────────────────
    h2 = [""]
    for _ in range(n_lv + 1):
        for out_label, _, _ in OUTCOMES:
            h2.append(out_label)
    lines.append(" & ".join(h2) + r" \\")

    # ── Header row 3: column numbers ───────────────────────────────────────────
    h3 = [""]
    for cn in range(1, n_data + 1):
        h3.append(f"({cn})")
    lines.append(" & ".join(h3) + r" \\")
    lines.append(r"\midrule")

    # ── One panel per regressor ────────────────────────────────────────────────
    for pi, lv_r in enumerate(LAYER_VALS):
        letter = chr(ord("A") + pi)
        lines.append(
            r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Panel "
            + letter + r": Regressor = " + LV_LABELS[lv_r]
            + r" connectivity}} \\"
        )

        def make_row(row_label, layer_fn, firm_fn, lv_r=lv_r):
            cells = [row_label]
            for lv_o in LAYER_VALS:
                for _, out_prefix, out_firm in OUTCOMES:
                    cells.append(layer_fn(lv_r, lv_o, out_prefix))
            for _, _, out_firm in OUTCOMES:
                cells.append(firm_fn(lv_r, out_firm))
            return cells

        lines.append(" & ".join(make_row(
            r"\quad Connectivity $\times$ Post",
            lambda lr, lo, op: fmt_coef(lget(lr, lo, op, "main")),
            lambda lr, of:     fmt_coef(fget(lr, of, "main")),
        )) + r" \\")

        lines.append(" & ".join(make_row(
            "",
            lambda lr, lo, op: fmt_se(lget(lr, lo, op, "main_se")),
            lambda lr, of:     fmt_se(fget(lr, of, "main_se")),
        )) + r" \\")

        lines.append(" & ".join(make_row(
            r"\quad Pre-trend (placebo)",
            lambda lr, lo, op: fmt_coef(lget(lr, lo, op, "pre")),
            lambda lr, of:     fmt_coef(fget(lr, of, "pre")),
        )) + r" \\")

        lines.append(" & ".join(make_row(
            "",
            lambda lr, lo, op: fmt_se(lget(lr, lo, op, "pre_se")),
            lambda lr, of:     fmt_se(fget(lr, of, "pre_se")),
        )) + r" \\")

        for si, (rt, stat_label, is_pval) in enumerate(STAT_ROWS):
            is_last = si == len(STAT_ROWS) - 1
            is_last_panel = pi == len(LAYER_VALS) - 1
            end = r" \\[6pt]" if is_last and not is_last_panel else r" \\"
            lines.append(" & ".join(make_row(
                r"\quad " + stat_label,
                lambda lr, lo, op, r=rt, p=is_pval: fmt_stat(lget(lr, lo, op, r), p),
                lambda lr, of, r=rt, p=is_pval:     fmt_stat(fget(lr, of, r), p),
            )) + end)

    # ── Spec footnote rows ─────────────────────────────────────────────────────
    lines.append(r"\midrule")
    lines.append(
        r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Specification}} \\"
    )
    spec_rows = [
        ("Layer-level outcomes",   ["\\checkmark"] * (n_lv * n_out) + ["---"] * n_out),
        ("Firm-level outcomes",    ["---"] * (n_lv * n_out) + ["\\checkmark"] * n_out),
        (r"Firm $\times$ year FE", ["\\checkmark"] * n_data),
    ]
    for row_label, col_marks in spec_rows:
        cells = [row_label] + col_marks
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\begin{tablenotes}[flushleft]")
    lines.append(
        r"\item \textit{Notes:} This table tests which occupation layer's connectivity to "
        r"treated firms drives the spillover effect. "
        r"Occupation layers follow the CBO 2002 first digit: "
        r"Managers (digit~1), Frontline High-Skills (digits~2--3), "
        r"Bureaucrat Lower (digit~4), Frontline Low-Skills (digit~5+). "
        r"Each panel uses a different connectivity regressor (identified by the panel heading). "
        r"Column groups correspond to the outcome layer (sub-sample of firm--layer--year observations). "
        r"The final two columns report firm-level regressions. "
        r"All layer-level regressions absorb firm$\times$year fixed effects. "
        r"The sample is restricted to untreated firms in the balanced firm panel, "
        r"above the median pre-treatment employment (2009--2011). "
        r"Connectivity is scaled to the 90th percentile of the control sample at 2009. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{tablenotes}")
    lines.append(r"\end{threeparttable}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── CSV builder ────────────────────────────────────────────────────────────────
def build_csv() -> pd.DataFrame:
    rows = []
    for lv_r in LAYER_VALS:
        for lv_o in LAYER_VALS:
            for out_label, out_prefix, out_firm in OUTCOMES:
                rows.append({
                    "layer":          LAYER,
                    "regressor":      lv_r,
                    "outcome_layer":  lv_o,
                    "outcome":        out_label,
                    "level":          "own" if lv_o == lv_r else "cross",
                    "main":           fmt_coef(lget(lv_r, lv_o, out_prefix, "main")),
                    "main_se":        fmt_se(  lget(lv_r, lv_o, out_prefix, "main_se")),
                    "pre":            fmt_coef(lget(lv_r, lv_o, out_prefix, "pre")),
                    "pre_se":         fmt_se(  lget(lv_r, lv_o, out_prefix, "pre_se")),
                    "pre_ftest":      fmt_stat(lget(lv_r, lv_o, out_prefix, "pre_ftest"), True),
                    "n_obs":          fmt_stat(lget(lv_r, lv_o, out_prefix, "n_obs")),
                    "n_firms":        fmt_stat(lget(lv_r, lv_o, out_prefix, "n_firms")),
                })
        for out_label, _, out_firm in OUTCOMES:
            rows.append({
                "layer":          LAYER,
                "regressor":      lv_r,
                "outcome_layer":  "firm",
                "outcome":        out_label,
                "level":          "firm",
                "main":           fmt_coef(fget(lv_r, out_firm, "main")),
                "main_se":        fmt_se(  fget(lv_r, out_firm, "main_se")),
                "pre":            fmt_coef(fget(lv_r, out_firm, "pre")),
                "pre_se":         fmt_se(  fget(lv_r, out_firm, "pre_se")),
                "pre_ftest":      fmt_stat(fget(lv_r, out_firm, "pre_ftest"), True),
                "n_obs":          fmt_stat(fget(lv_r, out_firm, "n_obs")),
                "n_firms":        fmt_stat(fget(lv_r, out_firm, "n_firms")),
            })
    return pd.DataFrame(rows)


# ── Write outputs ──────────────────────────────────────────────────────────────
TABLES.mkdir(parents=True, exist_ok=True)

tex_out = TABLES / "table_disentangle_occ4.tex"
csv_out = TABLES / "table_disentangle_occ4.csv"

tex_out.write_text(build_latex())
print(f"Wrote: {tex_out}")

df_out = build_csv()
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")
print()
print(df_out.to_string(index=False))

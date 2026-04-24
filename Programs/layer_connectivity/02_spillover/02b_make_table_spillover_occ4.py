"""
Assemble spillover table for the occ4 layer (above-median firm employment).

Reads CSVs produced by 07f_layer_spillover_occ4.do and outputs:
  Tables/layer_connectivity/table_layer_specs_abvmed_firm_occ4.tex
  Tables/layer_connectivity/table_layer_specs_abvmed_firm_occ4.csv

Specs included:
  (1) Within-firm FE     — firm×year FE, layer connectivity
  (2) Cross-firm FE      — micro×year + industry×year + mode×year FE
  (3) Firm-level restr.  — firm-level outcomes, standard FE, restricted sample

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/08e_make_table_layer_specs_abvmed_firm_occ4.py
"""

from pathlib import Path
import pandas as pd

PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"


def load_csv(path: Path) -> pd.DataFrame:
    rows = []
    with open(path) as f:
        for i, line in enumerate(f):
            line = line.rstrip("\n")
            if i == 0:
                continue
            parts = [p.strip('"') for p in line.split(";")]
            if len(parts) >= 5:
                rows.append({
                    "spec":     parts[0],
                    "section":  parts[1],
                    "outcome":  parts[2],
                    "row_type": parts[3],
                    "value":    parts[4],
                })
    return pd.DataFrame(rows)


LAYER = "occ4"

SPECS = [
    {
        "label":    "(1) Within-firm FE",
        "sublabel": r"firm$\times$year FE",
        "file_tpl": "results_spill_layer_{layer}_abvmed_firm_layer_spill.csv",
        "outcomes": ["lr_remdezr_layer", "l_layer_emp"],
    },
    {
        "label":    "(2) Cross-firm FE",
        "sublabel": r"micro$\times$yr + ind$\times$yr + mode$\times$yr",
        "file_tpl": "results_spill_layer_cross_{layer}_abvmed_firm_layer_spill.csv",
        "outcomes": ["lr_remdezr_layer", "l_layer_emp"],
    },
    {
        "label":    "(3) Firm-level (restricted)",
        "sublabel": "firm FE",
        "file_tpl": "results_spill_firmrestr_{layer}_abvmed_firm_layer_spill.csv",
        "outcomes": ["lr_remdezr_w", "l_firm_emp"],
    },
]

OUTCOME_ORDER = [
    ("Log Dec. wage",  "lr_remdezr_layer", "lr_remdezr_layer", "lr_remdezr_w"),
    ("Log employment", "l_layer_emp",      "l_layer_emp",      "l_firm_emp"),
]

STAT_ROWS = [
    ("n_obs",    "Observations"),
    ("n_cells",  r"Layers $\times$ firms"),
    ("n_firms",  "Firms"),
    ("pre_pval", r"Pre-trend F-test $p$-value"),
]


# ── Load data ──────────────────────────────────────────────────────────────────
data: dict = {}
missing: list = []

for si, spec in enumerate(SPECS):
    fpath = TABLES / spec["file_tpl"].format(layer=LAYER)
    if not fpath.exists():
        missing.append(str(fpath))
        continue
    for _, row in load_csv(fpath).iterrows():
        data[(si, row["outcome"], row["row_type"])] = row["value"]

if missing:
    print("WARNING — missing files:")
    for f in missing:
        print(f"  {f}")
    if len(missing) == len(SPECS):
        raise SystemExit("No data found. Exiting.")


def get(si, outcome, row_type, default="--"):
    return data.get((si, outcome, row_type), default)

def fmt_coef(v):
    return v.strip() if v.strip() not in ("--", "") else "--"

def fmt_se(v):
    s = v.strip()
    if s in ("--", ""):
        return "--"
    try:
        return f"({float(s):.4f})"
    except ValueError:
        return s

def fmt_stat(v, row_type):
    s = v.strip()
    if s in ("--", ""):
        return "---"
    if row_type == "pre_pval":
        try:
            return f"{float(s):.3f}"
        except ValueError:
            return s
    return s


# ── LaTeX builder ──────────────────────────────────────────────────────────────
def build_latex() -> str:
    n_spec    = len(SPECS)
    n_out     = len(OUTCOME_ORDER)
    ncols     = 1 + n_out * n_spec  # 1 + 2*3 = 7

    col_spec  = "l" + "ccc" * n_out
    lines     = []
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(
        r"\caption{Layer spillover effects, above-median firm employment "
        r"--- occupation layers (CBO 2002)}"
    )
    lines.append(r"\label{tab:layer_specs_abvmed_firm_occ4}")
    lines.append(r"\scriptsize")
    lines.append(r"\begin{threeparttable}")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    # Header row 1 — outcome groups
    h1 = [""]
    for out_label, *_ in OUTCOME_ORDER:
        h1.append(r"\multicolumn{" + str(n_spec) + r"}{c}{" + out_label + r"}")
    lines.append(" & ".join(h1) + r" \\")

    cmi = []
    col = 2
    for _ in OUTCOME_ORDER:
        cmi.append(f"\\cmidrule(lr){{{col}-{col+n_spec-1}}}")
        col += n_spec
    lines.append(" ".join(cmi))

    # Header row 2 — spec sub-labels
    h2 = [""]
    for _ in OUTCOME_ORDER:
        for spec in SPECS:
            h2.append(r"\shortstack{" + spec["label"].split(")")[0].strip("(")
                       + r" \\ " + spec["sublabel"] + r"}")
    lines.append(" & ".join(h2) + r" \\")

    # Header row 3 — sequential column numbers
    h3 = [""]
    for cn in range(1, n_out * n_spec + 1):
        h3.append(f"({cn})")
    lines.append(" & ".join(h3) + r" \\")
    lines.append(r"\midrule")

    # Panel for occ4 (single layer definition)
    lines.append(
        r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Occupation layers (CBO 2002): "
        r"Managers / High-skill / Bur.\ lower / Low-skill}} \\"
    )

    def cells_for_rt(rt, fmt_fn):
        row = [""]
        for _, out0, out1, out2 in OUTCOME_ORDER:
            out_per_spec = [out0, out1, out2]
            for si in range(n_spec):
                row.append(fmt_fn(get(si, out_per_spec[si], rt)))
        return row

    lines.append(" & ".join(cells_for_rt("main",    fmt_coef)) + r" \\")
    lines.append(" & ".join(cells_for_rt("main_se", fmt_se))   + r" \\")
    lines.append(" & ".join(cells_for_rt("pre",     fmt_coef)) + r" \\")
    lines.append(" & ".join(cells_for_rt("pre_se",  fmt_se))   + r" \\")

    for ri, (rt, stat_label) in enumerate(STAT_ROWS):
        stat_cells = [r"\quad " + stat_label]
        for _, out0, out1, out2 in OUTCOME_ORDER:
            out_per_spec = [out0, out1, out2]
            for si in range(n_spec):
                v = get(si, out_per_spec[si], rt, "--")
                if rt == "n_cells" and si == 2:
                    stat_cells.append("---")
                else:
                    stat_cells.append(fmt_stat(v, rt) if v != "--" else "---")
        lines.append(" & ".join(stat_cells) + r" \\")

    lines.append(r"\midrule")
    lines.append(r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Specification}} \\")

    CHECKMARK_ROWS = [
        ("Layer-level outcomes",    lambda si: si in (0, 1)),
        ("Firm-level outcomes",     lambda si: si == 2),
        (r"Firm $\times$ year FE",  lambda si: si == 0),
        ("Firm-level FE",           lambda si: si == 1),
        ("Firm FE",                 lambda si: si == 2),
    ]
    for label, cond in CHECKMARK_ROWS:
        cells = [label]
        for _ in OUTCOME_ORDER:
            for si in range(n_spec):
                cells.append(r"\checkmark" if cond(si) else "---")
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\begin{tablenotes}[flushleft]")
    within_cols = ", ".join(f"({1 + oi*n_spec})" for oi in range(n_out))
    cross_cols  = ", ".join(f"({2 + oi*n_spec})" for oi in range(n_out))
    firm_cols   = ", ".join(f"({3 + oi*n_spec})" for oi in range(n_out))
    lines.append(
        r"\item \textit{Notes:} This table reports spillover effects of layer-level connectivity to treated firms "
        r"for an occupation-based partition following the CBO 2002 first digit: "
        r"Managers (digit~1), Frontline High-Skills (digits~2--3), Bureaucrat Lower (digit~4), "
        r"Frontline Low-Skills (digit~5+). "
        r"The sample is restricted to firms above the median pre-treatment employment (2009--2011). "
        r"All regressions are restricted to untreated firms in the balanced firm panel. "
        r"Connectivity is scaled to the 90th percentile of the control sample at 2009. "
        r"The regression pools all four occupation layers (firm$\times$layer$\times$year observations). "
        r"Columns " + within_cols + r" (within-firm) absorb firm$\times$year FE; "
        r"columns " + cross_cols + r" (cross-firm) use microregion$\times$year, "
        r"industry$\times$year, and mode$\times$year FE; "
        r"columns " + firm_cols + r" (firm-level) run at the firm level on the layer-sample subset. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{tablenotes}")
    lines.append(r"\end{threeparttable}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


def build_csv() -> pd.DataFrame:
    rows = []
    for out_label, out0, out1, out2 in OUTCOME_ORDER:
        out_per_spec = [out0, out1, out2]
        for si, spec in enumerate(SPECS):
            rows.append({
                "layer":    LAYER,
                "spec":     spec["label"],
                "outcome":  out_label,
                "main":     fmt_coef(get(si, out_per_spec[si], "main")),
                "main_se":  fmt_se(  get(si, out_per_spec[si], "main_se")),
                "pre":      fmt_coef(get(si, out_per_spec[si], "pre")),
                "pre_se":   fmt_se(  get(si, out_per_spec[si], "pre_se")),
                "n_obs":    fmt_stat(get(si, out_per_spec[si], "n_obs"),    "n_obs"),
                "n_firms":  fmt_stat(get(si, out_per_spec[si], "n_firms"),  "n_firms"),
                "pre_pval": fmt_stat(get(si, out_per_spec[si], "pre_pval"), "pre_pval"),
            })
    return pd.DataFrame(rows)


# ── Write outputs ──────────────────────────────────────────────────────────────
TABLES.mkdir(parents=True, exist_ok=True)

tex_out = TABLES / "table_layer_specs_abvmed_firm_occ4.tex"
csv_out = TABLES / "table_layer_specs_abvmed_firm_occ4.csv"

tex_out.write_text(build_latex())
print(f"Wrote: {tex_out}")

df_out = build_csv()
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")
print()
print(df_out.to_string(index=False))

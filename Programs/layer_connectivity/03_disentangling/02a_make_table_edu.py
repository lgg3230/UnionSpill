"""
Assemble disentangling table for the 3-bin education layer (edu).

Layout: one panel per regressor (stacked vertically).
  Panel A: Regressor c_{0_no_hs}
  Panel B: Regressor c_{1_hs}
  Panel C: Regressor c_{2_higher}

Columns (13 total): for each outcome (3): No HS layer / HS layer / Higher ed. layer / Firm.

Output:
  Tables/layer_connectivity/table_disentangle_edu.tex / .csv

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/02a_make_table_edu.py
"""

from pathlib import Path
import pandas as pd

PROJ   = Path(__file__).resolve().parent.parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity/03_disentangling"
TEX_TABLES = TABLES / "tex_tables"

# ── CSV loader ────────────────────────────────────────────────────────────────
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

# ── Configuration ─────────────────────────────────────────────────────────────
LAYER = "edu"

LVS = ["0_no_hs", "1_hs", "2_higher"]   # regressors AND outcome-layer columns

LV_O_FIXED = LVS   # fixed column order (same for every panel)

LV_LABELS = {
    "0_no_hs":  "No HS",
    "1_hs":     "HS",
    "2_higher": "Higher ed.",
}

# (short label, layer-outcome prefix, firm-outcome key)
OUTCOMES = [
    ("Log Dec. wage",   "lr_remdezr_layer",  "lr_remdezr_w"),
    ("Log hourly wage", "lr_remdezr_h_layer", "lr_remdezr_h_w"),
    ("Log employment",  "l_layer_emp",        "l_firm_emp"),
]

LAYER_SECTION = "layer_firm_year"
FIRM_SECTION  = "firm_firm_year"

N_LV         = len(LVS)        # 3
N_OUT        = len(OUTCOMES)   # 3
COLS_PER_OUT = N_LV + 1        # 3 layer cols + 1 firm = 4
N_DATA       = N_OUT * COLS_PER_OUT   # 12
NCOLS        = 1 + N_DATA      # 13

# ── LaTeX helpers ─────────────────────────────────────────────────────────────
def lv_latex(lv: str) -> str:
    """Format lv as $c_{\\text{0\\_no\\_hs}}$ etc."""
    tex_name = lv.replace("_", r"\_")
    return f"$c_{{\\text{{{tex_name}}}}}$"

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

# ── Load data ─────────────────────────────────────────────────────────────────
fpath = TABLES / f"results_disentangle_{LAYER}_layer_spill.csv"
if not fpath.exists():
    raise SystemExit(f"Missing: {fpath}\nRun 01a_disentangle_edu.do first.")

data: dict = {}
for _, row in load_csv(fpath).iterrows():
    data[(row["section"], row["outcome"], row["row_type"])] = row["value"]

def get(section, outcome, row_type, default="--"):
    return data.get((section, outcome, row_type), default)

def lget(lv_r, lv_o, out_prefix, rt):
    return get(LAYER_SECTION, f"{out_prefix}_{lv_o}", f"c_{lv_r}_{rt}")

def fget(lv_r, out_firm, rt):
    return get(FIRM_SECTION, out_firm, f"c_{lv_r}_{rt}")

# ── LaTeX builder ─────────────────────────────────────────────────────────────
def build_latex(caption: str, label: str) -> str:
    lines = []

    col_spec = "l" + "c" * N_DATA
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{" + caption + r"}")
    lines.append(r"\label{" + label + r"}")
    lines.append(r"\resizebox{\textwidth}{!}{%")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    # ── Header row 1: outcome sub-groups (span COLS_PER_OUT = 4 each) ────────
    h1 = [""]
    for out_label, _, _ in OUTCOMES:
        h1.append(
            r"\multicolumn{" + str(COLS_PER_OUT) + r"}{c}{" + out_label + r"}"
        )
    lines.append(" & ".join(h1) + r" \\")

    cmi = []
    col = 2
    for _ in OUTCOMES:
        cmi.append(f"\\cmidrule(lr){{{col}-{col + COLS_PER_OUT - 1}}}")
        col += COLS_PER_OUT
    lines.append(" ".join(cmi))

    # ── Header row 2: specific lv_o labels + Firm, with sequential numbers ───
    h2 = [""]
    cn = 1
    for _ in OUTCOMES:
        for lv_o in LV_O_FIXED:
            h2.append(
                r"\shortstack{" + LV_LABELS[lv_o] + r" layer \\ (" + str(cn) + r")}"
            )
            cn += 1
        h2.append(r"\shortstack{Firm \\ (" + str(cn) + r")}")
        cn += 1
    lines.append(" & ".join(h2) + r" \\")
    lines.append(r"\midrule")

    # ── Panels (one per regressor) ────────────────────────────────────────────
    for pi, lv_r in enumerate(LVS):
        letter = chr(ord("A") + pi)
        lines.append(
            r"\multicolumn{" + str(NCOLS) + r"}{l}{\textit{Panel "
            + letter + r": Regressor " + lv_latex(lv_r) + r"}} \\"
        )

        def full_row(row_label, layer_fn, firm_fn, lv_r=lv_r):
            cells = [row_label]
            for _, out_layer, out_firm in OUTCOMES:
                for lv_o in LV_O_FIXED:
                    cells.append(layer_fn(lv_r, lv_o, out_layer))
                cells.append(firm_fn(lv_r, out_firm))
            return cells

        # Main coefficient row
        lines.append(" & ".join(full_row(
            r"\quad Connectivity $\times$ Post",
            lambda lr, lo, ol: fmt_coef(lget(lr, lo, ol, "main")),
            lambda lr, of:     fmt_coef(fget(lr, of, "main")),
        )) + r" \\")

        # SE row
        lines.append(" & ".join(full_row(
            "",
            lambda lr, lo, ol: fmt_se(lget(lr, lo, ol, "main_se")),
            lambda lr, of:     fmt_se(fget(lr, of, "main_se")),
        )) + r" \\")

        # Pre-trend row
        lines.append(" & ".join(full_row(
            r"\quad Pre-trend (placebo)",
            lambda lr, lo, ol: fmt_coef(lget(lr, lo, ol, "pre")),
            lambda lr, of:     fmt_coef(fget(lr, of, "pre")),
        )) + r" \\")

        # Pre-trend SE row
        lines.append(" & ".join(full_row(
            "",
            lambda lr, lo, ol: fmt_se(lget(lr, lo, ol, "pre_se")),
            lambda lr, of:     fmt_se(fget(lr, of, "pre_se")),
        )) + r" \\")

        STAT_ROWS = [
            ("Observations",
             lambda lr, lo, ol: fmt_stat(lget(lr, lo, ol, "n_obs")),
             lambda lr, of:     fmt_stat(fget(lr, of, "n_obs"))),
            ("Firms",
             lambda lr, lo, ol: fmt_stat(lget(lr, lo, ol, "n_firms")),
             lambda lr, of:     fmt_stat(fget(lr, of, "n_firms"))),
            ("Pre-trend F-test $p$-value",
             lambda lr, lo, ol: fmt_stat(lget(lr, lo, ol, "pre_ftest"), is_pval=True),
             lambda lr, of:     fmt_stat(fget(lr, of, "pre_ftest"), is_pval=True)),
        ]

        is_last_panel = pi == len(LVS) - 1
        for si, (stat_label, lfn, ffn) in enumerate(STAT_ROWS):
            is_last_stat = si == len(STAT_ROWS) - 1
            end = r" \\[6pt]" if is_last_stat and not is_last_panel else r" \\"
            lines.append(" & ".join(full_row(
                r"\quad " + stat_label, lfn, ffn,
            )) + end)

    # ── Spec rows ─────────────────────────────────────────────────────────────
    lines.append(r"\midrule")
    lines.append(r"\midrule")
    lines.append(
        r"\multicolumn{" + str(NCOLS) + r"}{l}{\textit{Specification}} \\"
    )

    # col_marks length = COLS_PER_OUT = 4
    spec_rows = [
        ("Layer-level outcomes", [r"\checkmark"] * N_LV + ["---"]),
        ("Firm-level outcomes",  ["---"] * N_LV + [r"\checkmark"]),
        ("Firm FE",              [r"\checkmark"] * COLS_PER_OUT),
        ("Year FE",              [r"\checkmark"] * COLS_PER_OUT),
    ]

    for row_label, col_marks in spec_rows:
        cells = [row_label]
        for _ in OUTCOMES:
            cells += col_marks
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")

    # Notes
    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} This table tests which education group's connectivity to treated firms "
        r"drives the spillover effect. Each panel uses a different connectivity variable as the regressor "
        r"(indicated in the panel title). "
        r"Within each outcome, the three layer-level columns show the outcome for workers in the "
        r"indicated education group (No HS / HS / Higher ed.); the fourth column is the firm-level outcome. "
        r"Layer-level regressions absorb firm FE and year FE; firm-level regressions absorb firm FE and year FE. "
        r"The regressor is the focal connectivity variable interacted with a "
        r"post-2012 indicator (S\'{u}mula 277 reform). "
        r"All regressions are restricted to untreated, balanced-panel firms. "
        r"Connectivity is scaled to the 90th percentile of the control sample at 2009. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── CSV builder ───────────────────────────────────────────────────────────────
def build_csv() -> pd.DataFrame:
    rows = []
    for lv_r in LVS:
        for out_label, out_layer, out_firm in OUTCOMES:
            for lv_o in LV_O_FIXED:
                rows.append({
                    "regressor": lv_r,
                    "outcome":   out_label,
                    "level":     "own_layer" if lv_o == lv_r else "cross_layer",
                    "lv_o":      lv_o,
                    "main":      fmt_coef(lget(lv_r, lv_o, out_layer, "main")),
                    "main_se":   fmt_se(  lget(lv_r, lv_o, out_layer, "main_se")),
                    "pre":       fmt_coef(lget(lv_r, lv_o, out_layer, "pre")),
                    "pre_se":    fmt_se(  lget(lv_r, lv_o, out_layer, "pre_se")),
                    "pre_ftest": fmt_stat(lget(lv_r, lv_o, out_layer, "pre_ftest"), is_pval=True),
                    "n_obs":     fmt_stat(lget(lv_r, lv_o, out_layer, "n_obs")),
                    "n_firms":   fmt_stat(lget(lv_r, lv_o, out_layer, "n_firms")),
                })
            rows.append({
                "regressor": lv_r,
                "outcome":   out_label,
                "level":     "firm",
                "lv_o":      "firm",
                "main":      fmt_coef(fget(lv_r, out_firm, "main")),
                "main_se":   fmt_se(  fget(lv_r, out_firm, "main_se")),
                "pre":       fmt_coef(fget(lv_r, out_firm, "pre")),
                "pre_se":    fmt_se(  fget(lv_r, out_firm, "pre_se")),
                "pre_ftest": fmt_stat(fget(lv_r, out_firm, "pre_ftest"), is_pval=True),
                "n_obs":     fmt_stat(fget(lv_r, out_firm, "n_obs")),
                "n_firms":   fmt_stat(fget(lv_r, out_firm, "n_firms")),
            })
    return pd.DataFrame(rows)


# ── Write outputs ─────────────────────────────────────────────────────────────
TABLES.mkdir(parents=True, exist_ok=True)

tex = build_latex(
    caption="Disentangling layer spillover effects --- 3-bin education",
    label="tab:disentangle_edu",
)
tex_out = TEX_TABLES / "table_disentangle_edu.tex"
tex_out.write_text(tex)
print(f"Wrote: {tex_out}")

df_out = build_csv()
csv_out = TABLES / "table_disentangle_edu.csv"
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")
print()
print(df_out.to_string(index=False))

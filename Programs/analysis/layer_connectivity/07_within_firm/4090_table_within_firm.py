#!/usr/bin/env python3
"""Build all six within-firm LaTeX tables (A6/A7/A8, monthly and hourly).

    ~/.conda/envs/venv_python312/bin/python 4090_table_within_firm.py

Inputs  (written by _run_within_firm_v2.do and _run_within_firm_hw_v2.do, in
         Tables/layer_connectivity/07_within_firm/):
    a6_group{,_hw}.csv, a6_partition{,_hw}.csv, a7{,_hw}.csv, a8{,_hw}.csv
Outputs (same directory):
    t_layerdesc{,_hw}.tex, t_groupspecs{,_hw}.tex, t_horserace{,_hw}.tex

Paper mapping ("Replication: Wages vs Hourly Wages"):
    Table 11 / 23  t_layerdesc{,_hw}   Group-Level Connectivity Descriptives
    Table 12 / 24  t_groupspecs{,_hw}  Group-level spillover effects
    Table 13 / 25  t_horserace{,_hw}   Group-Specific Connectivity and Firm-Level Outcomes

Each file is a complete `table` float, ready to \\input.

--------------------------------------------------------------------------------
PROVENANCE. Layout and formatting are vendored from the coauthor's
Programs/within_firm_final/scripts/archive/layer_connectivity_standalone/scripts/05b_make_tables_within_firm.py so this
pipeline carries no dependency on that package. Table geometry, column
formats, star thresholds and the A6/A8 notes are reproduced verbatim.

ONE DELIBERATE DIVERGENCE: the two Table A7 notes. The upstream text describes
the pre-revision fixed-effect list -- plain industry/microregion/month year
interactions, and no firm-level bins in "Overall". Our 01b_*.do estimates the
revised specification, so the upstream notes describe a regression we do not
run. They are rewritten below to match what the numbers actually come from.
See SPEC.md section 2.2 for the full fixed-effect lists.
--------------------------------------------------------------------------------
"""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

# Tables/layer_connectivity/07_within_firm, reached from Programs/.../07_within_firm
TABLE_DIR = (Path(__file__).resolve().parents[4]
             / "Tables" / "layer_connectivity" / "07_within_firm")

PANELS = [
    ("edu2", "Panel A:", "Education (no HS / HS+)"),
    ("gender", "Panel B:", "Gender (female / male)"),
    ("ten2", "Panel C:", r"Tenure ($<$12mo / $\geq$12mo)"),
]
PANEL_BY_PARTITION = {part: (part, panel, label) for part, panel, label in PANELS}

GROUPS = {
    "edu2": ("no_hs", "has_hs"),
    "gender": ("female", "male"),
    "ten2": ("lt12mo", "ge12mo"),
}
A8_LABELS = {
    "edu2": ("Low-Education Connectivity", "High-Education Connectivity"),
    "gender": ("Female Connectivity", "Male Connectivity"),
    "ten2": ("Low-Tenure Connectivity", "High-Tenure Connectivity"),
}
A6_HEADS = {
    "edu2": (r"\shortstack{No high\\school}", r"\shortstack{High\\school+}"),
    "gender": ("Female", "Male"),
    "ten2": (r"\shortstack{$<$12\\months}", r"\shortstack{$\geq$12\\months}"),
}
A6_SPANS = {"edu2": r"\textit{Education}", "gender": r"\textit{Gender}",
            "ten2": r"\textit{Tenure}"}


# ---------------------------------------------------------------- formatting --
def as_float(row: dict[str, str], key: str) -> float:
    val = row[key]
    return float(val) if val not in ("", ".") else math.nan


def stars(b: float, se: float) -> str:
    if not math.isfinite(b) or not math.isfinite(se) or se == 0:
        return ""
    z = abs(b / se)
    if z >= 2.575829:
        return "***"
    if z >= 1.959964:
        return "**"
    if z >= 1.644854:
        return "*"
    return ""


def fmt_num(x: float) -> str:
    """4dp with LaTeX math minus -- used in the A7 tabular (plain c columns)."""
    if not math.isfinite(x):
        return "---"
    s = f"{x:.4f}"
    if s.startswith("-"):
        s = "$-$" + s[1:]
    return s


def fmt_num_si(x: float) -> str:
    """4dp with an ASCII minus -- used in the A8 tabular (siunitx S columns)."""
    return "---" if not math.isfinite(x) else f"{x:.4f}"


def fmt_est(row: dict[str, str], key: str = "b", se_key: str = "se") -> str:
    b, se = as_float(row, key), as_float(row, se_key)
    return f"{fmt_num(b)}{stars(b, se)}"


def fmt_se(row: dict[str, str], key: str = "se") -> str:
    return f"({fmt_num(as_float(row, key))})"


def fmt_mean(row: dict[str, str], key: str = "meanpre") -> str:
    """Pre-treatment mean: 4 decimals in the CSV, 2 in the table
    (decision 2026-08-01)."""
    val = row.get(key, "")
    if val in ("", "."):
        return "---"
    v = float(val)
    return ("$-$" if v < 0 else "") + f"{abs(v):.3f}"


def fmt_int(row: dict[str, str], key: str) -> str:
    val = row[key]
    if val in ("", "."):
        return "---"
    return tex_int(float(val))


def tex_int(x: float) -> str:
    return f"{int(x):,}".replace(",", "{,}")


def si_cell(b: float, se: float) -> str:
    """A8 estimate cell: brace-wrap when stars make it non-numeric for siunitx."""
    st = stars(b, se)
    return f"{{{fmt_num_si(b)}{st}}}" if st else fmt_num_si(b)


def ctr(s: str) -> str:
    return rf"\multicolumn{{1}}{{c}}{{{s}}}"


def read_rows(path: Path, keys: tuple[str, ...]) -> dict[tuple[str, ...], dict[str, str]]:
    with path.open(newline="") as f:
        return {tuple(row[k] for k in keys): row for row in csv.DictReader(f)}


def read_list(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


# ------------------------------------------------------- Table 11 / 23 (A6) --
def make_layerdesc(group_rows, part_rows, *, hourly: bool, panels) -> str:
    parts = [p for p, _, _ in panels]
    by_group = {(r["partition"], r["group"]): r for r in group_rows}
    by_part = {r["partition"]: r for r in part_rows}

    ncol = 1 + 2 * len(parts)
    caption = "Group-Level Connectivity Descriptives"
    if hourly:
        caption += " --- hourly wages"

    spans, heads, cmids = [], [], []
    for i, p in enumerate(parts):
        spans.append(rf"\multicolumn{{2}}{{c}}{{{A6_SPANS[p]}}}")
        heads.extend(A6_HEADS[p])
        cmids.append(rf"\cmidrule(lr){{{2 + 2 * i}-{3 + 2 * i}}}")

    def row(label: str, fmt) -> str:
        cells = [fmt(by_group[(p, g)]) for p in parts for g in GROUPS[p]]
        return rf"    \quad {label} & " + " & ".join(cells) + r" \\"

    def prow(label: str, key: str) -> str:
        cells = [rf"\multicolumn{{2}}{{c}}{{{100 * float(by_part[p][key]):.1f}\%}}"
                 for p in parts]
        return rf"    \quad {label} & " + " & ".join(cells) + r" \\"

    wage_label = r"Avg.\ hourly wage" if hourly else r"Avg.\ wage"
    wage_fmt = ((lambda r: f"{float(r['avg_wage']):.1f}") if hourly
                else (lambda r: f"{float(r['avg_wage']):,.0f}"))

    out = [
        r"\begin{table}[H]",
        r"  \centering",
        rf"  \caption{{{caption}}}",
        r"  \footnotesize",
        rf"  \begin{{tabular}}{{l{'c' * (ncol - 1)}}}",
        r"    \toprule\toprule",
        "     & " + " & ".join(spans) + r" \\",
        "    " + " ".join(cmids),
        "     & " + " & ".join(heads) + r" \\",
        r"    \midrule",
        row(r"Avg.\ employment", lambda r: f"{float(r['avg_emp']):.1f}"),
        row(wage_label, wage_fmt),
        row(r"Avg.\ per-worker flows", lambda r: f"{float(r['avg_flows']):.4f}"),
        row("Connectivity", lambda r: f"{float(r['conn']):.4f}"),
        r"    \midrule",
        prow(r"\% firms w/ both groups", "pct_both"),
        prow(r"\% of connectivity variance within firms", "wi_pct"),
        prow(r"\% of connectivity variance between firms", "bw_pct"),
        r"    \bottomrule\bottomrule",
        r"  \end{tabular}",
        r"  \begin{minipage}{\linewidth}",
        r"    \scriptsize\vspace{4pt}",
    ]

    hourly_sentence = (
        "The average hourly wage row reports the level implied by the corrected "
        "layer-level hourly wage outcome, computed from natural-log real hourly wages "
        r"using monthly hours equal to \texttt{horascontr} $\times$ 4.348. "
        if hourly else ""
    )
    out.append(
        r"\textit{Notes:} This table summarizes pre-treatment (2009--2011) descriptive "
        "statistics for group-level connectivity under three worker partitions. The unit of "
        "observation is a group $\\times$ firm cell. " + hourly_sentence + "Tenure groups are "
        "defined by whether a worker has completed twelve months at the establishment. "
        "``Avg.\\ per-worker flows'' is total worker flows per group worker, averaged across "
        "year pairs 2007--08 through 2010--11. ``Connectivity'' is the average pre-treatment "
        "worker flow between a firm's group-$g$ workers and directly treated establishments, "
        "per group-$g$ worker; a firm's connectivity therefore varies across its worker "
        "groups. ``\\% firms w/ both groups'' is the share of spillover-sample firms with "
        "non-missing connectivity for both groups. The final two rows decompose the total "
        "variance of group connectivity into its within- and between-firm components on firms "
        "with both groups, following the ANOVA identity $\\mathrm{Var}(X) = "
        "\\mathrm{E}[\\mathrm{Var}(X \\mid \\mathrm{firm})] + \\mathrm{Var}(\\mathrm{E}[X "
        "\\mid \\mathrm{firm}])$, and report each as a share of the total."
    )
    out.extend([r"\end{minipage}", r"\end{table}"])
    return "\n".join(out) + "\n"


# ------------------------------------------------------- Table 12 / 24 (A7) --
# Shared description of the revised fixed-effect list. Both notes use it, so the
# monthly and hourly tables cannot drift apart.
_A7_SPEC = (
    r"In the ``Within firms'' and ``Overall'' columns, the unit of observation is a "
    r"group $\times$ firm $\times$ year cell and all regressions include group $\times$ "
    r"firm fixed effects, together with group-interacted year paths for industry, "
    r"microregion and negotiation-month, and group-interacted year-by-quartile-bin "
    r"controls for pre-treatment group wage, group employment and group per-worker "
    r"flows. ``Within firms'' columns add firm $\times$ year fixed effects, so "
    r"identification comes from differences in connectivity across the two groups of "
    r"the same firm-year. ``Overall'' columns instead add the firm-level pre-treatment "
    r"wage, employment and flow bins interacted with year, the same controls the "
    r"firm-level column uses. Employment regressions omit the wage bin, since for an "
    r"employment outcome the outcome bin and the size bin are the same variable. The "
    r"group-interacted terms cost 2.45\% to 3.52\% of observations to singleton "
    r"dropping in thin group $\times$ microregion $\times$ year cells."
)


def make_groupspecs(rows, *, hourly: bool, panels) -> str:
    wage_title = "Log Hourly Wages" if hourly else "Log Wages"
    title_suffix = r" (\textbf{log hourly wages})" if hourly else ""
    panel_labels = [label.split(" (", 1)[0].lower() for _, _, label in panels]
    caption_scope = ", ".join(panel_labels)
    out = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{Group-level spillover effects --- {caption_scope}{title_suffix}}}",
        r"\scriptsize",
        r"\begin{tabular}{lcccccc}",
        r"\toprule\toprule",
        rf" & \multicolumn{{3}}{{c}}{{{wage_title}}} & \multicolumn{{3}}{{c}}{{Log Employment}} \\",
        r"\cmidrule(lr){2-4} \cmidrule(lr){5-7}",
        r" & \shortstack{Firm-\\level} & \shortstack{Within\\firms} & Overall",
        r" & \shortstack{Firm-\\level} & \shortstack{Within\\firms} & Overall \\",
        r" & (1) & (2) & (3) & (4) & (5) & (6) \\",
        r"\midrule",
    ]

    for part, panel, label in panels:
        fw = rows[(part, "firm_full", "wage")]
        fe = rows[(part, "firm_full", "emp")]
        ww = rows[(part, "within", "wage")]
        ow = rows[(part, "overall", "wage")]
        we = rows[(part, "within", "emp")]
        oe = rows[(part, "overall", "emp")]
        out.extend([
            rf"\textbf{{{panel}}} {label} &  &  &  &  &  &  \\",
            rf"Connectivity $\times$ Post & {fmt_est(fw)} &  &  & {fmt_est(fe)} &  &  \\",
            rf" & {fmt_se(fw)} &  &  & {fmt_se(fe)} &  &  \\",
            rf"Group-Connectivity $\times$ Post &  & {fmt_est(ww)} & {fmt_est(ow)} &  & {fmt_est(we)} & {fmt_est(oe)} \\",
            rf" &  & {fmt_se(ww)} & {fmt_se(ow)} &  & {fmt_se(we)} & {fmt_se(oe)} \\",
            r" &  &  &  &  &  &  \\",
            rf"Pre-treatment mean & {fmt_mean(fw)} & {fmt_mean(ww)} & {fmt_mean(ow)} & {fmt_mean(fe)} & {fmt_mean(we)} & {fmt_mean(oe)} \\",
            rf"Observations & {fmt_int(fw, 'n')} & {fmt_int(ww, 'n')} & {fmt_int(ow, 'n')} & {fmt_int(fe, 'n')} & {fmt_int(we, 'n')} & {fmt_int(oe, 'n')} \\",
            rf"Groups $\times$ firms & --- & {fmt_int(ww, 'gxf')} & {fmt_int(ow, 'gxf')} & --- & {fmt_int(we, 'gxf')} & {fmt_int(oe, 'gxf')} \\",
            rf"Firms & {fmt_int(fw, 'firms')} & {fmt_int(ww, 'firms')} & {fmt_int(ow, 'firms')} & {fmt_int(fe, 'firms')} & {fmt_int(we, 'firms')} & {fmt_int(oe, 'firms')} \\",
            rf"Pre-trend (placebo) & {fmt_est(fw, 'bpre', 'sepre')} & {fmt_est(ww, 'bpre', 'sepre')} & {fmt_est(ow, 'bpre', 'sepre')} & {fmt_est(fe, 'bpre', 'sepre')} & {fmt_est(we, 'bpre', 'sepre')} & {fmt_est(oe, 'bpre', 'sepre')} \\",
            rf" & {fmt_se(fw, 'sepre')} & {fmt_se(ww, 'sepre')} & {fmt_se(ow, 'sepre')} & {fmt_se(fe, 'sepre')} & {fmt_se(we, 'sepre')} & {fmt_se(oe, 'sepre')} \\",
            r"\midrule",
        ])

    out.extend([
        r"\textbf{Additional Controls} &  &  &  &  &  &  \\",
        r"Group-level Variables &  & \checkmark & \checkmark &  & \checkmark & \checkmark \\",
        r"Firm $\times$ Year FE &  & \checkmark &  &  & \checkmark &  \\",
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
    ])

    if hourly:
        fw = rows[(panels[0][0], "firm_full", "wage")]
        note = (
            r"\begin{minipage}{\linewidth}\vspace{3pt}"
            r"\scriptsize\textit{Notes:} Hourly-wage counterpart of the group-level spillover "
            rf"table. The firm-level hourly spillover benchmark is {fmt_num(as_float(fw, 'b'))} "
            rf"with standard error {fmt_num(as_float(fw, 'se'))}. " + _A7_SPEC +
            r" Group-level employment columns are reported for completeness but remain "
            r"mechanically division-biased because group employment enters the connectivity "
            r"denominator. Standard errors are clustered by establishment. Hourly wages are "
            r"natural-log real hourly wages, computed with monthly hours equal to "
            r"\texttt{horascontr} $\times$ 4.348."
            r"\end{minipage}"
        )
    else:
        note = (
            r"\begin{minipage}{\linewidth}\vspace{4pt}"
            r"\scriptsize\textit{Notes:} Each panel partitions workers into two groups---by "
            r"education (Panel~A), gender (Panel~B), or tenure (Panel~C)---and estimates "
            r"spillover effects at the firm and group level, on the sample of untreated, "
            r"balanced-panel establishments. Group-Connectivity is defined analogously to "
            r"firm-level Connectivity, replacing total firm employment with group-specific "
            r"employment when normalizing worker flows to directly treated establishments. "
            r"Both measures are scaled so that a value of~1 corresponds to the 90th "
            r"percentile of the firm-level distribution. " + _A7_SPEC +
            r" Pre-trend (placebo) reports the coefficient from a placebo regression "
            r"estimated on pre-treatment data only (2009--2010 relative to 2011). "
            r"Pre-treatment mean is the mean of the dependent variable over 2009--2011 in the estimation sample of the corresponding column. "
            r"Standard errors clustered at the establishment level in parentheses. "
            r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
            r"\end{minipage}"
        )
    out.extend([note, r"\end{table}"])
    return "\n".join(out) + "\n"


# ------------------------------------------------------- Table 13 / 25 (A8) --
def make_horserace(rows, *, hourly: bool, panels) -> str:
    wage_head = r"\makecell{Log Hourly\\Wages}" if hourly else r"\makecell{Log\\Wages}"
    emp_head = r"\makecell{Log\\Employment}"
    caption = "Group-Specific Connectivity and Firm-Level Outcomes"
    if hourly:
        caption += " --- Log Hourly Wages"

    out = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{caption}}}",
        r"\footnotesize",
        r"\sbox0{%",
        r"\begin{tabular}{l S[table-format=-1.4] S[table-format=-1.4] "
        r"@{\hskip 20pt} S[table-format=-1.4] S[table-format=-1.4]}",
        r"\toprule\toprule",
        r" & \multicolumn{2}{c}{Post $\times$ Connectivity} & "
        r"\multicolumn{2}{c}{Pre-trend (placebo)} \\",
        r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}",
        rf"\textit{{Firm-level outcome:}} & {ctr(wage_head)} & {ctr(emp_head)} & "
        rf"{ctr(wage_head)} & {ctr(emp_head)} \\",
        rf" & {ctr('(1)')} & {ctr('(2)')} & {ctr('(3)')} & {ctr('(4)')} \\",
        r"\midrule",
    ]

    for idx, (part, panel, label) in enumerate(panels):
        w = rows[(part, "firm", "firm", "wage")]
        e = rows[(part, "firm", "firm", "emp")]
        lab1, lab2 = A8_LABELS[part]

        out.append(rf"\multicolumn{{5}}{{l}}{{\textbf{{{panel}}} {label}}} \\[2pt]")
        for i in (1, 2):
            lab = lab1 if i == 1 else lab2
            bw, sw = as_float(w, f"b{i}"), as_float(w, f"se{i}")
            be, se = as_float(e, f"b{i}"), as_float(e, f"se{i}")
            bpw, spw = as_float(w, f"bp{i}"), as_float(w, f"sp{i}")
            bpe, spe = as_float(e, f"bp{i}"), as_float(e, f"sp{i}")
            out.extend([
                rf"{lab} & {si_cell(bw, sw)} & {si_cell(be, se)} & "
                rf"{si_cell(bpw, spw)} & {si_cell(bpe, spe)} \\",
                rf" & {ctr(f'({fmt_num_si(sw)})')} & {ctr(f'({fmt_num_si(se)})')} & "
                rf"{ctr(f'({fmt_num_si(spw)})')} & {ctr(f'({fmt_num_si(spe)})')} \\",
                r"\addlinespace",
            ])
        peq_w = f"{as_float(w, 'peq'):.3f}"
        peq_e = f"{as_float(e, 'peq'):.3f}"
        out.extend([
            rf"Equality test ($p$-value) & {ctr(peq_w)} & {ctr(peq_e)} & & \\",
            rf"Pre-treatment mean & {ctr(fmt_mean(w))} & {ctr(fmt_mean(e))} & & \\",
            rf"Observations & {ctr(fmt_int(w, 'n'))} & {ctr(fmt_int(e, 'n'))} & & \\",
            rf"Firms & {ctr(fmt_int(w, 'firms'))} & {ctr(fmt_int(e, 'firms'))} & & \\",
        ])
        out.append(r"\midrule" if idx < len(panels) - 1 else r"\bottomrule\bottomrule")

    # Notes span the full text width, matching every other table in the
    # replication document (2026-08-02). Previously \wd0 -- the width of the
    # boxed table -- which squeezed the notes into a narrow column because this
    # table is only four numeric columns wide. The \sbox0/\usebox0 machinery is
    # kept: it still centres the table, it just no longer sizes the notes.
    out.extend([r"\end{tabular}}", r"\usebox0", r"\begin{minipage}{\linewidth}\vspace{4pt}"])

    lead = "Hourly-wage counterpart of the horse-race table. " if hourly else ""
    out.append(
        rf"\scriptsize\textit{{Notes:}} {lead}Each panel partitions workers into two groups and "
        "jointly estimates the spillover effects of the two resulting group-specific "
        "connectivity measures on firm-level outcomes, on the sample of untreated "
        "establishments. Low-education workers are those without a high school degree and "
        "high-education workers those with at least a high school degree; low-tenure workers "
        "are those with fewer than twelve months at the establishment and high-tenure workers "
        "those with twelve months or more. Both measures enter regressions simultaneously. "
        "Group-specific connectivity is defined as in the group-level spillover table, and "
        "both measures are scaled so that a value of~1 corresponds to the 90th percentile of "
        "the firm-level distribution. The unit of observation is a firm $\\times$ year cell, "
        "and all regressions include establishment fixed effects, year-interacted "
        "pre-treatment quartile bins of firm wage, firm employment and per-worker flows, and "
        "industry, microregion and negotiation-month interactions with year. Columns "
        "(1)--(2) report average effects for 2012--2016, with 2011 as the reference year. "
        "Columns (3)--(4) report coefficients from placebo regressions estimated on "
        "pre-treatment data only (2009--2010 relative to 2011); the equality test, "
        "observation counts, and firm counts refer to the specifications in columns "
        "(1)--(2). Equality test reports the $p$-value of the test that the two coefficients "
        "in the column are equal, using the normal approximation. Samples are smaller than in "
        "the main spillover table because both group-specific measures must be non-missing. "
        "Pre-treatment mean is the mean of the dependent variable over 2009--2011 in the estimation sample of the corresponding column. "
        "Standard errors clustered at the establishment level in parentheses. "
        "*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )
    out.extend([r"\end{minipage}", r"\end{table}"])
    return "\n".join(out) + "\n"


# ------------------------------------------------------------------- driver --
def build(out_dir: Path, partitions: list[str]) -> list[Path]:
    panels = [PANEL_BY_PARTITION[p] for p in partitions]
    written = []
    for hourly in (False, True):
        sfx = "_hw" if hourly else ""
        a6g = read_list(out_dir / f"a6_group{sfx}.csv")
        a6p = read_list(out_dir / f"a6_partition{sfx}.csv")
        a7 = read_rows(out_dir / f"a7{sfx}.csv", ("partition", "col", "outcome"))
        a8 = read_rows(out_dir / f"a8{sfx}.csv", ("partition", "col", "p90", "outcome"))

        targets = {
            f"t_layerdesc{sfx}.tex": make_layerdesc(a6g, a6p, hourly=hourly, panels=panels),
            f"t_groupspecs{sfx}.tex": make_groupspecs(a7, hourly=hourly, panels=panels),
            f"t_horserace{sfx}.tex": make_horserace(a8, hourly=hourly, panels=panels),
        }
        for name, body in targets.items():
            (out_dir / name).write_text(body)
            written.append(out_dir / name)
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=TABLE_DIR,
                        help="directory holding the a6/a7/a8 CSVs")
    parser.add_argument("--partitions", nargs="+", default=["edu2", "gender", "ten2"],
                        choices=sorted(PANEL_BY_PARTITION),
                        help="panels to include, in order")
    args = parser.parse_args()
    for p in build(args.output_dir, args.partitions):
        print(f"wrote {p}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python
"""
Two LaTeX tables:
  balance_permute.tex        (sideways) coef of each characteristic on connectivity
      at 3 control levels + placebo mean/p under each of 4 reshuffle schemes.
  horserace_recentered.tex   transposed: Real vs Recentered per outcome, panels per scheme,
      connectivity/expected-connectivity x Post and x Pre.
"""
import json
import pandas as pd
from pathlib import Path

TAB = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill/Tables/rand_inference")
DAT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/rand_inference")
SCH = ["unstrat", "ind_month", "ind_month_region", "ind_month_micro"]
SCHLAB = {"unstrat": "Unstrat.", "ind_month": "Ind$\\times$Mo",
          "ind_month_region": "$+$Region", "ind_month_micro": "$+$Micro"}
SCHLONG = {"unstrat": "Unstratified", "ind_month": "Industry $\\times$ Month",
           "ind_month_region": "Industry $\\times$ Month $\\times$ Region",
           "ind_month_micro": "Industry $\\times$ Month $\\times$ Microregion"}
LAB = {"lr_remdezr_w": "Log wages", "lr_remdezr_h_w": "Log hourly wages",
       "l_firm_emp": "Log employment", "numb_clauses": "CBA clauses",
       "flows": "Flows / worker", "hs": "HS share", "higher": "Higher-ed share",
       "female": "Share female", "nonwhite": "Share non-white", "age": "Mean age",
       "tenure": "Mean tenure"}
CORDER = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses", "flows",
          "hs", "higher", "female", "nonwhite", "age", "tenure"]
meta = json.load(open(DAT / "expected_exposure_meta.json"))

def f3(x): return "" if x is None or pd.isna(x) else f"{x:.3f}"
def f2(x): return "" if x is None or pd.isna(x) else f"{x:.2f}"
def stars_t(b, se):
    if b is None or se is None or pd.isna(b) or pd.isna(se) or se == 0: return ""
    t = abs(b / se)
    return "$^{***}$" if t > 2.576 else "$^{**}$" if t > 1.96 else "$^{*}$" if t > 1.645 else ""
def f3s(x, se): return "" if x is None or pd.isna(x) else f"{x:.3f}{stars_t(x, se)}"

# ══════════════════════════════ 1. BALANCE TABLE (sideways) ══════════════════
bp = json.load(open(DAT / "balance_permute.json"))
CHK = r"\checkmark"
CTRL = [("Industry FE", [0, 1, 1]), ("Negotiation-month FE", [0, 1, 1]),
        ("Microregion FE", [0, 1, 1]), ("Size quartile bins", [0, 0, 1]),
        ("Flow quartile bins", [0, 0, 1])]

def balance_table(suffix, label, fname, controlled):
    L = [r"\begin{table}[H]\centering",
         r"\caption{Balance: coefficient of each firm characteristic on connectivity, true vs.\ reshuffled treatment"
         + ("" if controlled else " (univariate placebo)") + "}",
         rf"\label{{{label}}}",
         r"{\setlength{\tabcolsep}{3pt}\scriptsize",
         r"\begin{tabular}{l ccc cccccccc}", r"\toprule",
         r" & \multicolumn{3}{c}{True conn.} & \multicolumn{8}{c}{Placebo, by reshuffle scheme} \\",
         r"\cmidrule(lr){2-4}\cmidrule(lr){5-12}",
         r" & Raw & \shortstack{$+$Ind,\\Mo, Mi} & \shortstack{$+$Size,\\Flow} & "
         + " & ".join(rf"\multicolumn{{2}}{{c}}{{{SCHLAB[s]}}}" for s in SCH) + r" \\",
         r" & & & & " + " & ".join("mean & $p$" for _ in SCH) + r" \\", r"\midrule"]
    for c in CORDER:
        r = bp[c]
        cells = [LAB[c], f3s(r["true_raw"], r.get("true_raw_se")),
                 f3s(r["true_fe"], r.get("true_fe_se")), f3s(r["true_main"], r.get("true_main_se"))]
        for s in SCH:
            cells += [f3(r[f"pl_{s}_mean{suffix}"]), f2(r[f"pl_{s}_p{suffix}"])]
        L.append(" & ".join(cells) + r" \\")
    L.append(r"\midrule")
    for name, inc in CTRL:
        cells = [name] + [CHK if v else "" for v in inc]
        cells += ([r"\multicolumn{2}{c}{" + CHK + "}"] * 4) if controlled else ([""] * 8)
        L.append(" & ".join(cells) + r" \\")
    if controlled:
        note = (r"The remaining columns report, for each reshuffle scheme, the mean coefficient when connectivity "
                r"is rebuilt from a permuted treated set (at the $+$Size,Flow control level) and the two-sided "
                r"permutation $p$-value for how far the true $+$Size,Flow coefficient (column 3) sits in that "
                r"placebo distribution.")
    else:
        note = (r"The remaining columns report, for each reshuffle scheme, the mean coefficient of a \emph{univariate} "
                r"regression (no controls) of the characteristic on the rebuilt connectivity, and the two-sided "
                r"permutation $p$-value for how far the true raw coefficient (column 1) sits in that placebo distribution.")
    L += [r"\bottomrule", r"\end{tabular}}",
          r"\begin{minipage}{\textwidth}\vspace{4pt}\scriptsize \textit{Notes:} Each cell in columns 1--3 is the "
          r"coefficient on connectivity in a regression of the 2011 firm characteristic on connectivity, across "
          r"untreated (spillover) establishments, at three control levels (Raw; adding industry, negotiation-month "
          r"and microregion fixed effects; adding size and flow quartile bins). " + note +
          r" A high $p$ means the association is the same whether or not the truly-treated firms carry the label, "
          r"i.e.\ it is mechanical rather than driven by treatment identity. Reshuffle schemes stratify on industry "
          r"$\times$ month, optionally $\times$ region (macro-region) or $\times$ microregion; 1{,}000 permutations. "
          r"Columns 1--3 report heteroskedasticity-robust significance ($^{*}p<0.10$, $^{**}p<0.05$, "
          r"$^{***}p<0.01$).\end{minipage}", r"\end{table}"]
    (TAB / fname).write_text("\n".join(L))
    print("wrote", TAB / fname)

balance_table("", "tab:balance_permute", "balance_permute.tex", controlled=True)
balance_table("_uni", "tab:balance_permute_univ", "balance_permute_univ.tex", controlled=False)

# ══════════════════════════════ 2. HORSE-RACE (transposed) ═══════════════════
h = pd.read_csv(TAB / "horserace_recentered.csv")
for cc in ["b", "se"]: h[cc] = pd.to_numeric(h[cc], errors="coerce")
OUT = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
def cell(out, scheme, coef):
    r = h[(h.outcome == out) & (h.scheme == scheme) & (h.coef == coef)]
    if r.empty or pd.isna(r.b.iloc[0]): return ""
    b, se = r.b.iloc[0], r.se.iloc[0]
    t = abs(b / se) if se and se > 0 else 0
    star = "$^{***}$" if t > 2.576 else "$^{**}$" if t > 1.96 else "$^{*}$" if t > 1.645 else ""
    return f"{b:.4f}{star}"

ROWS = [("conn_post", r"\quad Connectivity $\times$ Post"),
        ("conn_pre",  r"\quad Connectivity $\times$ Pre"),
        ("mu_post",   r"\quad Expected conn.\ $\times$ Post"),
        ("mu_pre",    r"\quad Expected conn.\ $\times$ Pre")]
L = [r"\begin{table}[H]\centering\scriptsize",
     r"\caption{Recentered horse-race: spillover effect, real assignment vs.\ recentered by expected connectivity}",
     r"\label{tab:horserace}", r"\begin{tabular}{l cccccccc}", r"\toprule",
     " & " + " & ".join(rf"\multicolumn{{2}}{{c}}{{{LAB[o]}}}" for o in OUT) + r" \\",
     "".join(rf"\cmidrule(lr){{{2+2*i}-{3+2*i}}}" for i in range(4)),
     " & " + " & ".join("Real & Recent." for _ in OUT) + r" \\", r"\midrule"]
for s in SCH:
    L.append(rf"\multicolumn{{9}}{{l}}{{\textit{{{SCHLONG[s]}}} ({meta[s]['swap_spillover']:,} swappable)}} \\")
    for coef, lab in ROWS:
        cells = [lab]
        for o in OUT:
            real = cell(o, "baseline", coef) if coef.startswith("conn") else ""   # baseline has no mu
            recent = cell(o, s, coef)
            cells += [real, recent]
        L.append(" & ".join(cells) + r" \\")
    L.append(r"\addlinespace")
L[-1] = r"\bottomrule"
L += [r"\end{tabular}",
      r"\begin{minipage}{\textwidth}\vspace{4pt}\scriptsize \textit{Notes:} Pooled spillover regression on "
      r"untreated establishments. `Real' is the baseline specification (connectivity $\times$ Post and its "
      r"2009--2011 placebo $\times$ Pre); `Recent.'\ adds the expected connectivity $\mu_i$ (mean across "
      r"permutations under the panel's scheme) interacted with Post and Pre. The baseline is identical across "
      r"panels and repeated for comparison. `Swappable' is the number of treated establishments that can be "
      r"relabeled under the scheme. CBA clauses use the collective-bargaining-period structure. Standard "
      r"errors clustered at the establishment level. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.\end{minipage}",
      r"\end{table}"]
(TAB / "horserace_recentered.tex").write_text("\n".join(L))
print("wrote", TAB / "horserace_recentered.tex")

# ══════════════════════════════ 3. PLACEBO CONTROL (connectivity to controls) ═
pc = pd.read_csv(TAB / "placebo_control.csv")
for cc in ["b", "se"]: pc[cc] = pd.to_numeric(pc[cc], errors="coerce")
def pcell(out, spec, coef):
    r = pc[(pc.outcome == out) & (pc.spec == spec) & (pc.coef == coef)]
    if r.empty or pd.isna(r.b.iloc[0]): return ""
    b, se = r.b.iloc[0], r.se.iloc[0]
    t = abs(b / se) if se and se > 0 else 0
    star = "$^{***}$" if t > 2.576 else "$^{**}$" if t > 1.96 else "$^{*}$" if t > 1.645 else ""
    return f"{b:.4f}{star}"
PROWS = [("conn_post", r"Connectivity $\times$ Post", "baseline"),
         ("conn_pre",  r"Connectivity $\times$ Pre",  "baseline"),
         ("ctrl_post", r"Control conn.\ $\times$ Post", None),
         ("ctrl_pre",  r"Control conn.\ $\times$ Pre",  None)]
L = [r"\begin{table}[H]\centering\scriptsize",
     r"\caption{Placebo: connectivity to control (untreated) firms as an additional control}",
     r"\label{tab:placebo_control}", r"\begin{tabular}{l cccccccc}", r"\toprule",
     " & " + " & ".join(rf"\multicolumn{{2}}{{c}}{{{LAB[o]}}}" for o in OUT) + r" \\",
     "".join(rf"\cmidrule(lr){{{2+2*i}-{3+2*i}}}" for i in range(4)),
     " & " + " & ".join("Real & $+$Ctrl" for _ in OUT) + r" \\", r"\midrule"]
for coef, lab, realspec in PROWS:
    cells = [lab]
    for o in OUT:
        real = pcell(o, realspec, coef) if realspec else ""
        cells += [real, pcell(o, "withctrl", coef)]
    L.append(" & ".join(cells) + r" \\")
L += [r"\bottomrule", r"\end{tabular}",
      r"\begin{minipage}{\textwidth}\vspace{4pt}\scriptsize \textit{Notes:} Pooled spillover regression on "
      r"untreated establishments. `Real' is the baseline (connectivity to treated firms $\times$ Post and its "
      r"2009--2011 placebo $\times$ Pre); `$+$Ctrl' adds connectivity to \emph{control} (untreated) firms, "
      r"interacted with Post and Pre. Connectivity to controls is built from the same pre-reform worker-flow "
      r"weights as the treated measure, summed over untreated Lagos firms, and normalized to its own 90th "
      r"percentile in the spillover sample. A near-zero control-connectivity coefficient with a stable treated "
      r"coefficient indicates it is connectivity to \emph{treated} firms specifically, not general connectivity, "
      r"that carries the effect. CBA clauses use the collective-bargaining-period structure. Standard errors "
      r"clustered at the establishment level. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.\end{minipage}",
      r"\end{table}"]
(TAB / "placebo_control.tex").write_text("\n".join(L))
print("wrote", TAB / "placebo_control.tex")

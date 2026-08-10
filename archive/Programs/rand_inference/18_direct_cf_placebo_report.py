#!/usr/bin/env python
"""
Report for the counterfactual-connectivity placebo (17_direct_cf_placebo.py).

Writes:
  Tables/rand_inference/direct_cf_placebo_summary.csv / .tex   compact headline table
  Tables/rand_inference/direct_cf_placebo_dist.csv             distribution + p-values
  Tables/rand_inference/direct_cf_placebo_diag.csv / .tex      selection diagnostics
  Graphs/rand_inference/direct_cf_placebo_A_<outcome>.pdf      Procedure A density
  Graphs/rand_inference/direct_cf_placebo_B_<outcome>.pdf      Procedure B density

Each figure shows the placebo distribution of the direct effect under permuted
pure-control classification, with vertical lines at the baseline (Panel C, all
controls) and the observed pure-control estimate (Panel A).
"""
import numpy as np, pandas as pd, json, argparse
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from matplotlib.lines import Line2D
from scipy.stats import gaussian_kde

ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
OUT  = ROOT / "Data/rand_inference"
TAB  = ROOT / "Tables/rand_inference"; TAB.mkdir(exist_ok=True)
GR   = ROOT / "Graphs/rand_inference"; GR.mkdir(exist_ok=True)

ap = argparse.ArgumentParser()
ap.add_argument("--scheme", default="intermediate")
args = ap.parse_args()

for p in ["/kellogg/proj/lgg3230/UnionSpill/Programs/fonts/LibertinusSerif-Regular.otf",
          "/kellogg/proj/lgg3230/UnionSpill/fonts/LibertinusSerif-Regular.otf"]:
    if Path(p).exists():
        fm.fontManager.addfont(p); plt.rcParams["font.family"] = "Libertinus Serif"; break
plt.rcParams.update({"font.size": 12})
BLUE, RED, GRAY, BLACK = "#2166AC", "#B2182B", "#666666", "#111111"

OUT_LAB = {"lr_remdezr_w": "Log wages", "lr_remdezr_h_w": "Log hourly wages",
           "l_firm_emp": "Log employment", "numb_clauses": "CBA clauses"}
PROC_LAB = {"A": "Procedure A: counterfactual zero connectivity",
            "B": "Procedure B: counterfactual bottom-46\\% connectivity"}

S = json.load(open(TAB / f"direct_cf_placebo_{args.scheme}.json"))
npz = np.load(OUT / f"direct_cf_placebo_{args.scheme}.npz")
outcomes = list(S["outcomes"].keys())
comp = pd.read_csv(TAB / f"direct_cf_composition_{args.scheme}.csv")

# ── compact headline table ──────────────────────────────────────────────────
rows = []
for o in outcomes:
    so = S["outcomes"][o]
    rows.append(dict(outcome=o, spec="Baseline direct effect (all controls, Panel C)",
                     estimate=so["panelC"]["b"], se=so["panelC"]["se"],
                     n_obs=so["panelC"]["n_obs"], n_controls=S["n_controls"]))
    rows.append(dict(outcome=o, spec="Observed pure-control direct effect (Panel A)",
                     estimate=so["panelA"]["b"], se=so["panelA"]["se"],
                     n_obs=so["panelA"]["n_obs"], n_controls=S["n_obs_pure"]))
    for t in ("A", "B"):
        s = so[f"proc{t}"]
        rows.append(dict(outcome=o, spec=f"Permutation mean, Procedure {t}",
                         estimate=s["mean"], se=s["mean_se"],
                         n_obs=float(np.mean(npz[f"{o}_{t}_n_obs"])),
                         n_controls=s["mean_n_ctrl"]))
summary = pd.DataFrame(rows)
summary.to_csv(TAB / f"direct_cf_placebo_summary_{args.scheme}.csv", index=False)
print(summary.to_string(index=False, float_format=lambda x: f"{x:,.4f}"))

# ── distribution + p-value table ────────────────────────────────────────────
drows = []
for o in outcomes:
    so = S["outcomes"][o]
    for t in ("A", "B"):
        s = so[f"proc{t}"]
        drows.append(dict(outcome=o, procedure=t, R=s["n_valid"],
                          mean=s["mean"], median=s["median"], sd=s["sd"],
                          **{f"p{q}": s["q"][str(q)] if str(q) in s["q"] else s["q"][q]
                             for q in (1, 5, 10, 25, 75, 90, 95, 99)},
                          panelC=so["panelC"]["b"], panelA=so["panelA"]["b"],
                          pctile_of_panelA=s["pct_of_obs_pure"],
                          p_upper=s["p_upper"], p_two_sided_vs_panelC=s["p_two_sided_vs_panelC"],
                          mean_n_ctrl=s["mean_n_ctrl"], mean_overlap=s["mean_overlap"]))
dist = pd.DataFrame(drows)
dist.to_csv(TAB / f"direct_cf_placebo_dist_{args.scheme}.csv", index=False)

# ── diagnostics table ───────────────────────────────────────────────────────
diag = pd.DataFrame([
    dict(diagnostic="Actual control firms (Panel C)", value=S["n_controls"]),
    dict(diagnostic="Controls with observed zero connectivity (Panel A)", value=S["n_obs_pure"]),
    dict(diagnostic="Share of controls that are observed pure", value=round(S["pure_share"], 4)),
    dict(diagnostic="Controls with no flow edge at all (always counterfactual-zero)",
         value=S["n_isolated_controls"]),
    dict(diagnostic="W-reconstructed pure controls at the observed treated set",
         value=S["w_validation"]["n_w_pure"]),
    dict(diagnostic="Jaccard, W-reconstructed vs panel-defined pure set",
         value=round(S["w_validation"]["jaccard"], 4)),
    dict(diagnostic="Treated firms permuted (swappable)", value=S["swappable_treated"]),
    dict(diagnostic="Mixed strata", value=S["mixed_strata"]),
])
for t in ("A", "B"):
    s = S["outcomes"][outcomes[0]][f"proc{t}"]
    diag = pd.concat([diag, pd.DataFrame([
        dict(diagnostic=f"Procedure {t}: mean controls kept", value=round(s["mean_n_ctrl"], 1)),
        dict(diagnostic=f"Procedure {t}: min / max controls kept",
             value=f"{s['min_n_ctrl']} / {s['max_n_ctrl']}"),
        dict(diagnostic=f"Procedure {t}: mean overlap with observed pure set",
             value=round(s["mean_overlap"], 4)),
    ])], ignore_index=True)
diag.to_csv(TAB / f"direct_cf_placebo_diag_{args.scheme}.csv", index=False)
print("\n" + diag.to_string(index=False))

# ── figures ─────────────────────────────────────────────────────────────────
for o in outcomes:
    so = S["outcomes"][o]
    bC, bA = so["panelC"]["b"], so["panelA"]["b"]
    for t in ("A", "B"):
        b = npz[f"{o}_{t}_b"]; b = b[~np.isnan(b)]
        s = so[f"proc{t}"]
        fig, ax = plt.subplots(figsize=(7.2, 4.4))
        lo = min(b.min(), bC, bA); hi = max(b.max(), bC, bA)
        pad = 0.12 * (hi - lo)
        ax.hist(b, bins=40, density=True, color="#BFD3E6", edgecolor="white", linewidth=0.6)
        xs = np.linspace(lo - pad, hi + pad, 400)
        ax.plot(xs, gaussian_kde(b)(xs), color=GRAY, linewidth=1.4)
        ax.axvline(bC, color=BLUE, linestyle="--", linewidth=2)
        ax.axvline(bA, color=RED, linestyle="-", linewidth=2)
        ax.set_xlim(lo - pad, hi + pad)
        ax.set_xlabel("Direct effect (treated $\\times$ post)", fontweight="bold")
        ax.set_ylabel("Density", fontweight="bold")
        ax.spines[["top", "right"]].set_visible(False)
        handles = [
            Line2D([], [], color="#BFD3E6", linewidth=8,
                   label=f"Placebo draws ($R$={s['n_valid']:,})"),
            Line2D([], [], color=BLUE, linestyle="--", linewidth=2,
                   label=f"Baseline, all controls = {bC:.4f}"),
            Line2D([], [], color=RED, linewidth=2,
                   label=f"Observed pure controls = {bA:.4f}"),
        ]
        ax.legend(handles=handles, loc="upper center", bbox_to_anchor=(0.5, -0.18),
                  ncol=2, frameon=False, fontsize=10)
        ax.text(0.02, 0.96, f"{OUT_LAB.get(o, o)}\nProcedure {t}: "
                            f"$p$={s['p_upper']:.3f}, mean controls={s['mean_n_ctrl']:.0f}",
                transform=ax.transAxes, va="top", ha="left", fontsize=10, color=BLACK)
        fig.tight_layout()
        fig.savefig(GR / f"direct_cf_placebo_{t}_{o}_{args.scheme}.pdf", bbox_inches="tight")
        plt.close(fig)
        print("saved:", GR / f"direct_cf_placebo_{t}_{o}_{args.scheme}.pdf")


# ── LaTeX: compact headline table ───────────────────────────────────────────
def fmt(x, d=4):
    return f"{x:,.{d}f}"


prim = outcomes[0]
L = [r"\begin{table}[H]", r"\centering", r"\scriptsize",
     r"\caption{Counterfactual-connectivity placebo: direct effect under permuted pure-control classification}",
     r"\label{tab:direct_cf_placebo}",
     r"\begin{tabular}{l" + "cccc" * len(outcomes) + "}", r"\toprule"]
hdr = " & ".join([r"\multicolumn{4}{c}{" + OUT_LAB.get(o, o) + "}" for o in outcomes])
L += [" & " + hdr + r" \\"]
L += [r"\cmidrule(lr){2-5}" + (r"\cmidrule(lr){6-9}" if len(outcomes) > 1 else "")]
sub = " & ".join([r"\shortstack{Est.} & \shortstack{S.E.} & \shortstack{$N$} & \shortstack{Control\\firms}"
                  for o in outcomes])
L += ["Specification & " + sub + r" \\", r"\midrule"]
specs = [("Baseline direct effect (all controls)", "panelC", None),
         ("Observed pure controls (zero connectivity)", "panelA", None),
         ("Permutation mean, Procedure A", None, "A"),
         ("Permutation mean, Procedure B", None, "B")]
for lab, key, t in specs:
    cells = []
    for o in outcomes:
        so = S["outcomes"][o]
        if key:
            cells += [fmt(so[key]["b"]), f"({fmt(so[key]['se'])})",
                      f"{so[key]['n_obs']:,}",
                      f"{(S['n_controls'] if key == 'panelC' else S['n_obs_pure']):,}"]
        else:
            s = so[f"proc{t}"]
            cells += [fmt(s["mean"]), f"({fmt(s['mean_se'])})",
                      f"{np.mean(npz[f'{o}_{t}_n_obs']):,.0f}", f"{s['mean_n_ctrl']:,.0f}"]
    L.append(lab + " & " + " & ".join(cells) + r" \\")
L += [r"\midrule"]
for t in ("A", "B"):
    cells = []
    for o in outcomes:
        s = S["outcomes"][o][f"proc{t}"]
        cells += [r"\multicolumn{4}{c}{" + f"{s['p_upper']:.3f}" + "}"]
    L.append(f"Randomization $p$-value, Procedure {t} & " + " & ".join(cells) + r" \\")
L += [r"\bottomrule", r"\end{tabular}",
      r"\begin{minipage}{\textwidth}\vspace{2mm}\scriptsize",
      r"\textit{Notes:} This table reports a randomization-inference-style robustness exercise for the "
      r"direct effect. The actual treated group and the treatment indicator in the regression are held "
      r"fixed throughout; what varies across permutation draws is only the connectivity object used to "
      r"classify untreated firms as ``pure'' controls. Each draw reshuffles the treated label within "
      r"strata over the analysis sample, rebuilds counterfactual connectivity for every actual control "
      r"firm, and reselects the control group: Procedure A keeps controls with counterfactual zero "
      r"connectivity; Procedure B keeps the bottom " +
      f"{S['pure_share']*100:.1f}" + r"\% of controls by counterfactual connectivity, the empirical "
      r"share of observed pure controls, so that the placebo control group matches the observed one in "
      r"size. The regression specification, outcome, fixed effects, clustering and sample restrictions "
      r"are identical to the main direct-effect specification. The randomization $p$-value is the share "
      r"of draws whose placebo estimate weakly exceeds the observed pure-control estimate. Permutation "
      r"draws: $R=" + f"{S['R']:,}" + r"$, stratification scheme: " + args.scheme.replace("_", " ") +
      r". This is a placebo-style validation exercise, not a formally established estimator.",
      r"\end{minipage}", r"\end{table}"]
(TAB / f"direct_cf_placebo_summary_{args.scheme}.tex").write_text("\n".join(L) + "\n")
print("saved:", TAB / f"direct_cf_placebo_summary_{args.scheme}.tex")

# ── LaTeX: composition / diagnostics table ──────────────────────────────────
CL = [r"\begin{table}[H]", r"\centering", r"\scriptsize",
      r"\caption{Composition of the control groups under observed and counterfactual connectivity}",
      r"\label{tab:direct_cf_composition}",
      r"\begin{tabular}{lcccccc}", r"\toprule",
      r"Control group & \shortstack{Control\\firms} & \shortstack{Log\\employment} & "
      r"\shortstack{Employment} & \shortstack{Worker\\flows} & \shortstack{Flow\\partners} & "
      r"\shortstack{Share in\\observed pure} \\", r"\midrule"]
for _, r_ in comp.iterrows():
    CL.append(f"{r_.group} & {r_.n_controls:,.0f} & {r_.l_firm_emp:.2f} & {r_.firm_emp:,.1f} & "
              f"{r_.totalflows:.4f} & {r_.n_edges:.2f} & {r_.is_obs_pure:.3f} \\\\")
CL += [r"\bottomrule", r"\end{tabular}",
       r"\begin{minipage}{\textwidth}\vspace{2mm}\scriptsize",
       r"\textit{Notes:} This table compares the pre-treatment composition of the control groups "
       r"entering the baseline direct-effect specification (all controls), the observed pure-control "
       r"specification (untreated firms with zero observed connectivity to the treated set), and the "
       r"two counterfactual-connectivity placebo selections, averaged across permutation draws. "
       r"``Flow partners'' is the number of analysis-sample firms with which the control firm exchanges "
       r"any worker over 2007--2011. Procedure A keeps controls with counterfactual zero connectivity; "
       r"Procedure B keeps the bottom " + f"{S['pure_share']*100:.1f}" + r"\% of controls by "
       r"counterfactual connectivity. The comparison shows that neither placebo rule reproduces the "
       r"composition of the observed pure-control group, which should be borne in mind when reading the "
       r"placebo distributions.",
       r"\end{minipage}", r"\end{table}"]
(TAB / f"direct_cf_placebo_composition_{args.scheme}.tex").write_text("\n".join(CL) + "\n")
print("saved:", TAB / f"direct_cf_placebo_composition_{args.scheme}.tex")

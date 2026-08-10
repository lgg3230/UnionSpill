#!/usr/bin/env python
"""Fill the randomization-inference section template (spillover + direct, four
outcomes, four resolutions) and splice it into the paper's Main_Results.tex."""
import json
from pathlib import Path

ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
TAB  = ROOT / "Tables/rand_inference"
SEC  = Path("/tmp/claude-6216/-gpfs-kellogg-proj-lgg3230-UnionSpill/"
            "12b7011b-6c90-498a-bb73-28c7794341b6/scratchpad/randinf_section.tex")
MR   = ROOT / "UnionSpill-paper/Main_Results.tex"

RES = ["none", "coarse", "medium", "fine"]
res = {(mode, r): json.load(open(TAB / f"perm_{mode}_{r}.json"))
       for mode in ["spillover", "direct"] for r in RES}
OUT_TAG = {"lr_remdezr_w": "W", "lr_remdezr_h_w": "H", "l_firm_emp": "E", "numb_clauses": "C"}
MODE_TAG = {"spillover": "S", "direct": "D"}
RES_TAG = {"none": "N", "coarse": "C", "medium": "M", "fine": "F"}

def beta(mode, o):  return res[(mode, "none")][o]["delta_obs"]
def pval(mode, o, r): return res[(mode, r)][o]["p_two_sided"]
def fmt_beta(o, x): return f"${x:.3f}$" if o == "numb_clauses" else f"${x:.4f}$"
def fmt_p(x):       return f"${x:.4f}$"

sub = {}
for mode, mt in MODE_TAG.items():
    for o, ot in OUT_TAG.items():
        sub[f"@@{mt}{ot}B@@"] = fmt_beta(o, beta(mode, o))
        for r, rt in RES_TAG.items():
            sub[f"@@{mt}{ot}{rt}@@"] = fmt_p(pval(mode, o, r))

# max spillover wage/hourly p over the informative (non-fine) resolutions
s_pmax = max(pval("spillover", o, r) for o in ["lr_remdezr_w", "lr_remdezr_h_w"]
             for r in ["none", "coarse", "medium"])
sub["@@S_PMAX@@"]  = f"{s_pmax:.4f}"
sub["@@PFLOOR@@"]  = "0.0001"

section = SEC.read_text()
for k, v in sub.items():
    section = section.replace(k, v)
assert "@@" not in section, "unfilled placeholder: " + section[section.index("@@"):section.index("@@")+12]

txt = MR.read_text()
start = "\\section{Randomization Inference: Permuting the Identity of the Treated Set}"
end   = "\\section{Sensitivity to Parallel Trends: Honest DiD}"
i, j = txt.index(start), txt.index(end)
MR.write_text(txt[:i] + section + "\\clearpage\n\n" + txt[j:])
print("spliced. spillover wage/hourly p:",
      {r: (round(pval("spillover","lr_remdezr_w",r),4), round(pval("spillover","lr_remdezr_h_w",r),4)) for r in RES})
print("direct wage/hourly/clauses p:",
      {r: (round(pval("direct","lr_remdezr_w",r),4), round(pval("direct","numb_clauses",r),4)) for r in RES})

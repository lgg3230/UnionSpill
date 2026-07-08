#!/usr/bin/env python3
"""
_build_log_variants.py

Mechanically generate LOG (log1p, zeros-retained) variants of the 11 CBA-similarity
scripts that contain a log-similarity block. The change being implemented:

    OLD:  gen double ln_`v' = ln(`v') if `v' > 0     (drops zero-similarity obs)
    NEW:  gen double ln_`v' = ln(1 + `v')            (log1p, retains zeros)

Everything for the log variants is isolated into a parallel pipeline so the
original scripts and their outputs are never modified:

    Tables/cba_similarity      -> Tables/cba_similarity_log
    Graphs/cba_similarity      -> Graphs/cba_similarity_log
    Logs/cba_similarity        -> Logs/cba_similarity_log

For each source <name>.do this writes:
    <name>_log.do            (transform swapped, outputs redirected, raw-table
                              generator call disabled so raw tex is untouched)
    _run_<name>_log.do       (globals wrapper)
For each ln-generator the scripts call, a <gen>_log.py copy is written that reads
and writes under cba_similarity_log and updates the zero-handling note.

Run:  ~/.conda/envs/venv_python312/bin/python Programs/cba_similarity/_build_log_variants.py
"""

import re
from pathlib import Path

HERE = Path(__file__).resolve().parent                 # Programs/cba_similarity
PROJECT = HERE.parent.parent                           # UnionSpill

SCRIPTS = [
    "cba_similarity",
    "cba_similarity_avg",
    "cba_similarity_corr_w",
    "cba_similarity_pretreat_ref",
    "cba_similarity_pretreat_ref_uncorr_w",
    "cba_similarity_focal_frozen",
    "cba_self_similarity",
    "treated_cba_similarity",
    "treated_cba_self_similarity",
    "treated_cba_similarity_pretreat_ref",
    "treated_cba_similarity_pretreat_ref_uncorr_w",
]

# The exact (indent-independent) substring of the zero-dropping log transform.
OLD_TRANSFORM = "gen double ln_`v' = ln(`v') if `v' > 0"
NEW_TRANSFORM = "gen double ln_`v' = ln(1 + `v')"

WRAPPER_TEMPLATE = """* Wrapper: set globals then run {name}_log.do
set more off
set varabbrev off

if "`c(username)'" == "lgg3230" {{
\tglobal main "/kellogg/proj/lgg3230"
}}
else if "`c(username)'" == "luisg" {{
\tglobal main "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster"
}}
else {{
\tdi as error "Unknown username: `c(username)'. Set global main manually."
\texit 1
}}

global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global programs  "$main/UnionSpill/Programs"

do "$programs/cba_similarity/{name}_log.do"
"""


def transform_do(text: str, name: str) -> tuple[str, set[str]]:
    """Return (modified do-file text, set of ln-generator .py basenames called)."""
    if OLD_TRANSFORM not in text:
        raise SystemExit(f"{name}.do: expected transform line not found")

    # 1) swap the transform (keep zeros)
    text = text.replace(OLD_TRANSFORM, NEW_TRANSFORM)

    # 2) redirect output directories (NOT $programs/cba_similarity)
    text = text.replace("$tables/cba_similarity/", "$tables/cba_similarity_log/")
    text = text.replace("$graphs/cba_similarity/", "$graphs/cba_similarity_log/")
    text = text.replace("$logs/cba_similarity/",   "$logs/cba_similarity_log/")

    ln_gens: set[str] = set()
    out_lines = []
    for line in text.splitlines():
        m = re.search(r'generate_(\S*?)latex\.py', line)
        if m and "shell" in line:
            pyname = m.group(0)  # e.g. generate_ln_similarity_latex.py
            if re.search(r'ln', pyname):
                # ln generator -> point to its _log copy
                log_pyname = pyname.replace("latex.py", "latex_log.py")
                line = line.replace(pyname, log_pyname)
                ln_gens.add(pyname)
            else:
                # raw-table generator -> disable so original raw tex is untouched
                line = "* [log variant] raw-table generator disabled: " + line.lstrip()
        # customise notify message
        if "notify " in line and "source" in line:
            line = re.sub(r'notify "([^"]*)"', r'notify "\1 (log1p)"', line)
        out_lines.append(line)

    return "\n".join(out_lines) + "\n", ln_gens


def transform_generator(text: str) -> str:
    """Point a ln-generator copy at the cba_similarity_log pipeline and fix the note."""
    # redirect the output/input directory token (quoted, standalone path component)
    text = text.replace('"cba_similarity"', '"cba_similarity_log"')
    # update the zero-handling sentence where present
    text = text.replace(
        "observations with similarity equal to zero are excluded.",
        "the outcome is $\\ln(1+\\text{similarity})$, so zero-similarity observations are retained.",
    )
    return text


def main() -> None:
    for sub in ("Tables", "Graphs", "Logs"):
        (PROJECT / sub / "cba_similarity_log").mkdir(parents=True, exist_ok=True)

    all_ln_gens: set[str] = set()
    for name in SCRIPTS:
        src = HERE / f"{name}.do"
        text = src.read_text(encoding="utf-8")
        new_text, ln_gens = transform_do(text, name)
        (HERE / f"{name}_log.do").write_text(new_text, encoding="utf-8")
        (HERE / f"_run_{name}_log.do").write_text(
            WRAPPER_TEMPLATE.format(name=name), encoding="utf-8"
        )
        all_ln_gens |= ln_gens
        print(f"  {name}_log.do  (ln-gen: {sorted(ln_gens)})")

    for pyname in sorted(all_ln_gens):
        gsrc = HERE / pyname
        if not gsrc.exists():
            print(f"  !! generator missing: {pyname}")
            continue
        gtext = transform_generator(gsrc.read_text(encoding="utf-8"))
        out = HERE / pyname.replace("latex.py", "latex_log.py")
        out.write_text(gtext, encoding="utf-8")
        print(f"  {out.name}")

    print(f"\nBuilt {len(SCRIPTS)} _log.do scripts and {len(all_ln_gens)} _log generators.")


if __name__ == "__main__":
    main()

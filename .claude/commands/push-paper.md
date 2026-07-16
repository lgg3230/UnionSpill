---
description: Commit and push local changes to the UnionSpill-paper (Overleaf) repo
---

Run the shell script `/kellogg/proj/lgg3230/UnionSpill/Programs/push_paper.sh` via Bash and report its output verbatim.

If the user passed arguments ($ARGUMENTS), forward them to the script. A bare string is used as the commit message; supported flags: `-n` / `--dry-run`.

Do not do anything else. Do not edit files, and do not `git add` anything by hand — the script stages tracked changes only (`git add -u`) and refuses to commit LaTeX build artifacts. If the user needs a NEW file included, tell them to `git add` it first rather than doing it for them.

The script rebases onto origin before pushing, so an Overleaf-side edit is never clobbered. If the rebase stops on a conflict, report that verbatim and stop — do not attempt to resolve it.

After the script exits, summarize in one sentence:
- what was committed (message and how many files),
- whether the rebase pulled anything new in from Overleaf,
- whether the push succeeded.

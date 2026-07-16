---
description: Pull latest changes from the UnionSpill-paper (Overleaf) repo
---

Run the shell script `/kellogg/proj/lgg3230/UnionSpill/Programs/pull_paper.sh` via Bash and report its output verbatim.

If the user passed arguments ($ARGUMENTS), forward them to the script (supported flags: `--keep-mine`, `--keep-theirs`).

Do not do anything else. Do not stage, commit, push, or edit any files. The script handles stash-pop conflicts on its own (default: keep upstream).

After the script exits, summarize in one sentence:
- whether the pull was a fast-forward (and how many commits/files),
- whether a stash was created, and whether it popped cleanly or was kept around due to a conflict.

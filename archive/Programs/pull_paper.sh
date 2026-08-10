#!/usr/bin/env bash
# Pull latest from the Overleaf-backed UnionSpill-paper repo.
#
# Usage:
#   Programs/pull_paper.sh              # pull, auto-stash local edits
#   Programs/pull_paper.sh --keep-mine  # on conflict during pop, keep local
#   Programs/pull_paper.sh --keep-theirs# on conflict during pop, keep upstream (default)
#
# On stash-pop conflict the script never leaves conflict markers in the tree:
# it resolves per the chosen policy and keeps the stash entry around so the
# discarded side can still be recovered manually via:
#   cd UnionSpill-paper && git stash show -p stash@{0}

set -euo pipefail

REPO_DIR="/kellogg/proj/lgg3230/UnionSpill/UnionSpill-paper"
POLICY="theirs"  # which side wins if stash-pop conflicts: theirs=upstream, mine=local

for arg in "$@"; do
    case "$arg" in
        --keep-mine)   POLICY="mine"   ;;
        --keep-theirs) POLICY="theirs" ;;
        -h|--help)
            sed -n '2,12p' "$0"
            exit 0
            ;;
        *) echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
done

cd "$REPO_DIR"

echo "== fetching =="
git fetch origin

BRANCH=$(git symbolic-ref --short HEAD)
echo "on branch $BRANCH"

if ! git diff-index --quiet HEAD --; then
    echo "== local changes present, stashing =="
    git stash push -m "pull_paper.sh auto-stash $(date +%Y-%m-%d_%H-%M-%S)"
    STASHED=1
else
    STASHED=0
fi

echo "== pulling =="
git pull --ff-only origin "$BRANCH"

if [ "$STASHED" -eq 1 ]; then
    echo "== restoring stashed edits =="
    if git stash pop; then
        echo "stash applied cleanly"
    else
        echo "stash pop conflicted; resolving with policy=$POLICY"
        # In a stash pop:
        #   --ours   = current working tree (upstream after pull)
        #   --theirs = stashed content (your local edits)
        CONFLICTED=$(git diff --name-only --diff-filter=U)
        for f in $CONFLICTED; do
            if [ "$POLICY" = "theirs" ]; then
                # keep upstream = working-tree-pre-pop side
                git checkout HEAD -- "$f"
            else
                # keep local = stashed side
                git checkout --theirs -- "$f"
                git add "$f"
                git reset HEAD -- "$f"
            fi
        done
        echo "conflicts resolved; stash entry preserved (see 'git stash list')"
    fi
fi

echo "== status =="
git status -s
echo "== done =="

if [ -f /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh ]; then
    # shellcheck disable=SC1091
    source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh
    notify "Paper repo pulled" "UnionSpill-paper pull complete (policy=$POLICY)"
fi

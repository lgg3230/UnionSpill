#!/usr/bin/env bash
# Usage: source Programs/notify.sh
#        notify "Job done" "Optional longer message"

NTFY_TOPIC="lgg3230-kellogg"

notify() {
    local title="${1:-UnionSpill}"
    local message="${2:-}"
    curl -s -o /dev/null \
        -H "Title: ${title}" \
        -d "${message:-${title}}" \
        "https://ntfy.sh/${NTFY_TOPIC}"
}

#!/bin/bash
# capture-candidate.sh — Claude Code SessionEnd hook for Gregor's KB.
#
# Deterministic, zero-LLM capture nudge: when a session ends with enough
# substance (> 8 user turns, not a /clear), append it to
# $KB_DATA_DIR/.librarian/capture-queue.tsv. The next session's ambient
# payload lists these as UNFILED SESSIONS; saying "file #N" hands the
# transcript to `scripts/librarian file` in the background. Entries expire
# after 14 days (filtered at read time; the queue is pruned on dequeue).
#
# This deliberately does NOT auto-file: one human bit ("worth keeping?") stays
# exactly where a human is cheapest.
#
# Disable hatch: `touch $KB_DATA_DIR/.no-capture-queue`.

set -u
trap 'exit 0' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${KB_ENGINE_DIR:=$(dirname "$SCRIPT_DIR")}"
: "${KB_DATA_DIR:=$KB_ENGINE_DIR/kb-data}"

JQ="${JQ:-/usr/bin/jq}"
QUEUE="$KB_DATA_DIR/.librarian/capture-queue.tsv"
MIN_USER_TURNS=8

[ -f "$KB_DATA_DIR/.no-capture-queue" ] && exit 0
command -v "$JQ" >/dev/null 2>&1 || exit 0

PAYLOAD=""
while IFS= read -t 5 -r line; do PAYLOAD+="$line"$'\n'; done 2>/dev/null || true
[ -z "$PAYLOAD" ] && exit 0

REASON="$(printf '%s' "$PAYLOAD" | "$JQ" -r '.reason // ""' 2>/dev/null || echo "")"
[ "$REASON" = "clear" ] && exit 0
TRANSCRIPT="$(printf '%s' "$PAYLOAD" | "$JQ" -r '.transcript_path // empty' 2>/dev/null || true)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | "$JQ" -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# Substance heuristic: count real user text turns in the JSONL transcript.
NTURNS="$("$JQ" -rs '[.[] | select(.type == "user" and (.message.content | type) == "string")] | length' "$TRANSCRIPT" 2>/dev/null || echo 0)"
[ "${NTURNS:-0}" -gt "$MIN_USER_TURNS" ] || exit 0

# Already queued (or a KB session about the KB itself)? Skip duplicates.
mkdir -p "$(dirname "$QUEUE")"
touch "$QUEUE"
grep -qF "$TRANSCRIPT" "$QUEUE" && exit 0

# First user message as the snippet (one line, tab-safe, capped).
SNIPPET="$("$JQ" -rs '[.[] | select(.type == "user" and (.message.content | type) == "string")][0].message.content // ""' "$TRANSCRIPT" 2>/dev/null | tr '\t\n' '  ' | cut -c1-100)"

printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION_ID" "$TRANSCRIPT" "$SNIPPET" >> "$QUEUE"

# Prune: drop lines older than 14 days so the queue can't grow unbounded.
CUTOFF="$(date -u -v-14d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '14 days ago' +%Y-%m-%dT%H:%M:%SZ)"
awk -F'\t' -v c="$CUTOFF" '$1 >= c' "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"

exit 0

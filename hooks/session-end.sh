#!/bin/bash
# session-end.sh — Claude Code SessionEnd hook for Gregor's KB.
#
# Reads the hook payload from stdin, extracts session_id and transcript_path,
# and spawns the librarian in the background (fire-and-forget) so the
# terminal does NOT hang waiting for filing to complete.
#
# Hook payload shape (best-effort — we only require session_id and
# transcript_path):
#   {
#     "session_id": "...",
#     "transcript_path": "/path/to/transcript.jsonl",
#     "cwd": "...",
#     "hook_event_name": "SessionEnd",
#     "reason": "logout" | "clear" | "other"
#   }

set -u

# Resolve paths: prefer env (set by install into settings.json), else derive
# from this script's location (hooks/ -> repo root -> kb-data).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${KB_ENGINE_DIR:=$(dirname "$SCRIPT_DIR")}"
: "${KB_DATA_DIR:=$KB_ENGINE_DIR/kb-data}"

LIBRARIAN="$KB_ENGINE_DIR/scripts/librarian"
JQ="${JQ:-/usr/bin/jq}"

# Always exit 0 — hook failures must not impede the user's session exit.
trap 'exit 0' EXIT

# Read payload from stdin. Claude Code closes stdin after sending the JSON,
# so cat returns naturally. Use a bash-builtin read loop with a per-line
# timeout as a belt-and-suspenders guard (macOS has no `timeout` by default).
PAYLOAD=""
while IFS= read -t 5 -r line; do
  PAYLOAD+="$line"$'\n'
done
[ -z "$PAYLOAD" ] && exit 0

SESSION_ID=$(printf '%s' "$PAYLOAD" | "$JQ" -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
TRANSCRIPT=$(printf '%s' "$PAYLOAD" | "$JQ" -r '.transcript_path // empty' 2>/dev/null || true)
REASON=$(printf '%s' "$PAYLOAD" | "$JQ" -r '.reason // ""' 2>/dev/null || echo "")

# No transcript → nothing to file.
[ -z "$TRANSCRIPT" ] && exit 0
[ -f "$TRANSCRIPT" ] || exit 0

# Skip on /clear — the user just wiped context, doesn't want it filed.
[ "$REASON" = "clear" ] && exit 0

# Quick disable hatch: drop a file at this path to skip auto-filing without
# editing settings.json. Useful when debugging the KB itself.
[ -f "$KB_DATA_DIR/.no-auto-file" ] && exit 0

# Fire-and-forget. nohup + disown so the librarian survives this hook
# returning. stdout/stderr → /dev/null because the librarian writes its
# own log.
nohup "$LIBRARIAN" file \
  --transcript "$TRANSCRIPT" \
  --session-id "$SESSION_ID" \
  </dev/null >/dev/null 2>&1 &
disown

exit 0

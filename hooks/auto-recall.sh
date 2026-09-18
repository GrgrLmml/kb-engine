#!/bin/bash
# auto-recall.sh — Claude Code UserPromptSubmit hook for Gregor's KB.
#
# Scores each user prompt against the KB (`kb recall`: head-vector cosine +
# corroborated BM25, thresholds calibrated on the _eval.yaml no-hit set) and
# injects at most 3 relevant leaves as additionalContext. Also records the
# session's transcript path per cwd for `kb file --session auto`. Session-scoped
# dedupe: the same entry is never injected twice into one session.
#
# Registered by install.sh. Disable hatch: `touch $KB_DATA_DIR/.no-auto-recall`.
# Failures/silence never block the prompt (always exit 0, empty output = no-op).

set -u
trap 'exit 0' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${KB_ENGINE_DIR:=$(dirname "$SCRIPT_DIR")}"
: "${KB_DATA_DIR:=$KB_ENGINE_DIR/kb-data}"

[ -f "$KB_DATA_DIR/.no-auto-recall" ] && exit 0
[ -x "$KB_ENGINE_DIR/scripts/kb" ] || exit 0
command -v uv >/dev/null 2>&1 || exit 0

PAYLOAD=""
while IFS= read -t 2 -r _line; do PAYLOAD+="$_line"$'\n'; done 2>/dev/null || true
[ -z "$PAYLOAD" ] && exit 0

PROMPT="$(printf '%s' "$PAYLOAD" | /usr/bin/jq -r '.prompt // empty' 2>/dev/null || true)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | /usr/bin/jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"

# Record this cwd's live session (transcript path) so `kb file --session auto`
# can find the conversation to file without the LLM guessing at paths. Keyed
# by cwd: the latest prompt in a cwd is, at /file-this time, this session.
TRANSCRIPT="$(printf '%s' "$PAYLOAD" | /usr/bin/jq -r '.transcript_path // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$PAYLOAD" | /usr/bin/jq -r '.cwd // empty' 2>/dev/null || true)"
if [ -n "$TRANSCRIPT" ] && [ -n "$CWD" ]; then
  SLUG="$(printf '%s' "$CWD" | sed -E 's/[^A-Za-z0-9]+/-/g; s/^-|-$//g')"
  mkdir -p "$KB_DATA_DIR/.index/sessions" 2>/dev/null && \
    printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","at":"%s"}\n' \
      "$SESSION_ID" "$TRANSCRIPT" "$CWD" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      > "$KB_DATA_DIR/.index/sessions/$SLUG.json" 2>/dev/null || true
fi

# Skip trivial prompts and slash commands — kb recall re-checks length anyway.
[ "${#PROMPT}" -lt 20 ] && exit 0
case "$PROMPT" in /*) exit 0 ;; esac

HITS="$(printf '%s' "$PROMPT" | KB_DATA_DIR="$KB_DATA_DIR" \
  "$KB_ENGINE_DIR/scripts/kb" recall --session-id "$SESSION_ID" -n 3 2>/dev/null)" || exit 0
[ -n "$HITS" ] || exit 0

export HITS
python3 - <<'PYEOF'
import json, os
hits = os.environ["HITS"]
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": f"""<kb-auto-recall>
The KB has prior context that may match this prompt (auto-retrieved; judge
relevance yourself and mention it only if actually useful):
{hits}
</kb-auto-recall>""",
    }
}))
PYEOF

exit 0

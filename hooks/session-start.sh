#!/bin/bash
# session-start.sh — Claude Code SessionStart hook for Gregor's KB.
#
# Injects the tiered ambient payload (`kb ambient`) into every new session:
#   Tier A (always, ~2k tokens): folder map + recipe triggers
#   Tier B (cwd-relevant): full entry lists for KB folders matching this repo
#   Tier C (deltas): problems brief, fresh nightly digest, unfiled-session queue
# The per-entry map for everything else stays one call away (kb routes --compact).
#
# Registered by install.sh with matcher "startup|clear" so resumed sessions
# don't get a duplicate copy.
#
# Disable hatch: `touch $KB_DATA_DIR/.no-ambient` to pause without editing
# settings. Failures never block session start (always exit 0).

set -u
trap 'exit 0' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${KB_ENGINE_DIR:=$(dirname "$SCRIPT_DIR")}"
: "${KB_DATA_DIR:=$KB_ENGINE_DIR/kb-data}"

# Read the hook payload; the session cwd drives Tier B relevance.
PAYLOAD=""
while IFS= read -t 2 -r _line; do PAYLOAD+="$_line"; done 2>/dev/null || true

[ -f "$KB_DATA_DIR/.no-ambient" ] && exit 0
[ -x "$KB_ENGINE_DIR/scripts/kb" ] || exit 0
command -v uv >/dev/null 2>&1 || exit 0

CWD="$(printf '%s' "$PAYLOAD" | /usr/bin/jq -r '.cwd // empty' 2>/dev/null || true)"

if [ -n "$CWD" ]; then
  INDEX="$(KB_DATA_DIR="$KB_DATA_DIR" "$KB_ENGINE_DIR/scripts/kb" ambient --cwd "$CWD" 2>/dev/null)" || exit 0
else
  INDEX="$(KB_DATA_DIR="$KB_DATA_DIR" "$KB_ENGINE_DIR/scripts/kb" ambient 2>/dev/null)" || exit 0
fi
[ -n "$INDEX" ] || exit 0

# Hard cap so a runaway corpus can never flood the context (~15k tokens).
MAXCHARS=60000
if [ "${#INDEX}" -gt "$MAXCHARS" ]; then
  INDEX="${INDEX:0:$MAXCHARS}
[... ambient payload truncated at ${MAXCHARS} chars — something is wrong; check kb ambient ...]"
fi

export INDEX KB_ENGINE_DIR
python3 - <<'PYEOF'
import json, os

index = os.environ["INDEX"]
engine = os.environ["KB_ENGINE_DIR"]
context = f"""<kb-ambient-index>
This is the ambient map of Gregor's personal knowledge base (auto-injected at session start).
It is the FOLDER-level map plus recipe triggers — NOT the full entry list.
Use it to notice when prior context exists. To act on it:
- `{engine}/scripts/kb search <terms>` — hybrid ranked search (or the /find command)
- `{engine}/scripts/kb routes --compact` — the full one-line-per-entry map
- `{engine}/scripts/kb show <id>` — print a full entry (or /promote <id>)
- for questions answered INSIDE transcripts (exact commands, "how did we…", multi-entry overviews): delegate to the `kb-researcher` subagent (or /ask) instead of reading transcripts here
- an OPEN PROBLEMS block below means the theory layer has unresolved conflicts: /criticize designs experiments, /run-experiment resolves them

{index}
</kb-ambient-index>"""
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}))
PYEOF

exit 0

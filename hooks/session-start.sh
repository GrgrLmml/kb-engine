#!/bin/bash
# session-start.sh — Claude Code SessionStart hook for Gregor's KB.
#
# Injects the COMPACT KB index (folder purposes + one line per entry + recipe
# triggers, a few thousand tokens) into every new session as additionalContext.
# This makes the KB ambient: the model starts out knowing what exists and can
# /find, /promote, or kb-search on its own initiative instead of flying blind.
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

# Drain stdin (the hook JSON payload); we don't need it.
while IFS= read -t 2 -r _line; do :; done 2>/dev/null || true

[ -f "$KB_DATA_DIR/.no-ambient" ] && exit 0
[ -x "$KB_ENGINE_DIR/scripts/kb" ] || exit 0
command -v uv >/dev/null 2>&1 || exit 0

INDEX="$(KB_DATA_DIR="$KB_DATA_DIR" "$KB_ENGINE_DIR/scripts/kb" routes --compact 2>/dev/null)" || exit 0
[ -n "$INDEX" ] || exit 0

# Hard cap so a runaway corpus can never flood the context (~15k tokens).
MAXCHARS=60000
if [ "${#INDEX}" -gt "$MAXCHARS" ]; then
  INDEX="${INDEX:0:$MAXCHARS}
[... index truncated at ${MAXCHARS} chars — corpus has outgrown ambient injection; see docs/plan-day2.md Phase 4 ...]"
fi

export INDEX KB_ENGINE_DIR
python3 - <<'PYEOF'
import json, os

index = os.environ["INDEX"]
engine = os.environ["KB_ENGINE_DIR"]
context = f"""<kb-ambient-index>
This is the compact index of Gregor's personal knowledge base (auto-injected at session start).
One line per entry: `id — one-line summary`, grouped by folder; recipe triggers at the end.
Use it to notice when prior context exists. To act on it:
- `{engine}/scripts/kb search <terms>` — ranked full-text search (or the /find command)
- `{engine}/scripts/kb show <id>` — print a full entry (or /promote <id>)
- for questions answered INSIDE transcripts (exact commands, "how did we…", multi-entry overviews): delegate to the `kb-researcher` subagent (or /ask) instead of reading transcripts here
Do not treat this index as complete detail — it is the WARM-tier map, not the content.

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

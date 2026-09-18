#!/bin/bash
# check-tool-output.sh — Claude Code PostToolUse hook for Gregor's KB.
#
# "Things are not as they appear": when an EXTERNAL knowledge tool (an MCP
# server such as a code-search bot, Slack, Jira; WebFetch) returns text that
# touches a subject the KB holds a current claim on, inject those claims as
# additionalContext so the model compares before it repeats the tool's answer.
# Deterministic (`kb check`), silent when nothing matches, never blocks.
#
# Registered by install.sh with matcher "mcp__.*|WebFetch". Bash output is
# deliberately not matched (too noisy). Disable hatch:
#   touch $KB_DATA_DIR/.no-check-tool-output

set -u
trap 'exit 0' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${KB_ENGINE_DIR:=$(dirname "$SCRIPT_DIR")}"
: "${KB_DATA_DIR:=$KB_ENGINE_DIR/kb-data}"

[ -f "$KB_DATA_DIR/.no-check-tool-output" ] && exit 0
[ -x "$KB_ENGINE_DIR/scripts/kb" ] || exit 0
command -v uv >/dev/null 2>&1 || exit 0

PAYLOAD=""
while IFS= read -t 3 -r _line; do PAYLOAD+="$_line"$'\n'; done 2>/dev/null || true
[ -z "$PAYLOAD" ] && exit 0

TOOL="$(printf '%s' "$PAYLOAD" | /usr/bin/jq -r '.tool_name // empty' 2>/dev/null || true)"
# the KB's own MCP server answering is not an external claim to check
case "$TOOL" in mcp__kb__*) exit 0 ;; esac

# tool_response may be a string, an object, or a list of content blocks
TEXT="$(printf '%s' "$PAYLOAD" | /usr/bin/jq -r '
  .tool_response
  | if type == "string" then .
    elif type == "array" then map(if type == "object" then (.text // .content // "" | tostring) else tostring end) | join("\n")
    elif type == "object" then (.text // .content // .result // .) | tostring
    else tostring end' 2>/dev/null | head -c 20000)"
[ "${#TEXT}" -lt 80 ] && exit 0

HITS="$(printf '%s' "$TEXT" | KB_DATA_DIR="$KB_DATA_DIR" "$KB_ENGINE_DIR/scripts/kb" check 2>/dev/null)" || exit 0
[ -n "$HITS" ] || exit 0

export HITS TOOL
python3 - <<'PYEOF'
import json, os
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": f"""<kb-check tool="{os.environ['TOOL']}">
The KB holds current, dated claims on subjects this tool result touches. Compare before
relying on the result: where they disagree, say so and cite the KB claim's since/source
(or, if the tool is right and the KB stale, file the correction).
{os.environ['HITS']}
</kb-check>""",
    }
}))
PYEOF
exit 0

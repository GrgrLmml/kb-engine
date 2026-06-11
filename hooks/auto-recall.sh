#!/bin/bash
# auto-recall.sh — EXPERIMENTAL Claude Code UserPromptSubmit hook for Gregor's KB.
#
# On every prompt, runs a fast BM25 search of the prompt text against the KB
# index and injects the top hits (above a score threshold) as additionalContext
# — true ambient memory. Noise-risky by design, therefore NOT registered by
# install.sh. To try it, add to ~/.claude/settings.json:
#
#   "hooks": {
#     "UserPromptSubmit": [
#       { "hooks": [ { "type": "command",
#                      "command": "$KB_ENGINE_DIR/hooks/auto-recall.sh",
#                      "timeout": 15 } ] }
#     ]
#   }
#
# Disable hatch without editing settings: `touch $KB_DATA_DIR/.no-auto-recall`.
# Failures never block the prompt (always exit 0).

set -u
trap 'exit 0' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${KB_ENGINE_DIR:=$(dirname "$SCRIPT_DIR")}"
: "${KB_DATA_DIR:=$KB_ENGINE_DIR/kb-data}"

[ -f "$KB_DATA_DIR/.no-auto-recall" ] && exit 0
[ -x "$KB_ENGINE_DIR/scripts/kb" ] || exit 0
command -v uv >/dev/null 2>&1 || exit 0

# Capture the hook payload here — the python heredoc below consumes stdin
# for the script itself, so the payload must travel via the environment.
HOOK_PAYLOAD="$(cat 2>/dev/null || true)"

export KB_ENGINE_DIR KB_DATA_DIR HOOK_PAYLOAD
python3 - <<'PYEOF'
import json, os, re, subprocess, sys

MIN_PROMPT_CHARS = 20   # too short = no signal
MIN_SCORE = 8.0         # bm25 threshold — tune after a week of use
MAX_HITS = 3

try:
    payload = json.loads(os.environ.get("HOOK_PAYLOAD") or "{}")
except Exception:
    sys.exit(0)
prompt = (payload.get("prompt") or "").strip()
if len(prompt) < MIN_PROMPT_CHARS or prompt.startswith("/"):
    sys.exit(0)
# strip code blocks / paths — they search badly and dominate the token set
prompt = re.sub(r"```.*?```", " ", prompt, flags=re.S)
# drop stopwords/filler: common words rack up BM25 across an OR-query and make
# small talk cross the threshold
STOP = set("""the this that these those with from into onto about above below
and but for nor not are was were been being have has had having does did doing
can could should would will shall may might must ok okay yes yeah sure please
thanks thank sounds good great fine just like want need lets let go ahead
proceed approach way thing things stuff also very really then than when where
what which who whom how why all any both each few more most other some such
out off over under again further once here there now new use using used make
your you our they them their its his her she him""".split())
toks = [t for t in re.findall(r"[A-Za-z0-9_-]{3,}", prompt)
        if t.lower() not in STOP][:24]
if len(toks) < 2:
    sys.exit(0)

try:
    r = subprocess.run(
        [os.environ["KB_ENGINE_DIR"] + "/scripts/kb", "search", *toks,
         "--json", "-n", str(MAX_HITS)],
        capture_output=True, text=True, timeout=12,
        env={**os.environ},
    )
    hits = json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else []
except Exception:
    sys.exit(0)

hits = [h for h in hits if h.get("score", 0) >= MIN_SCORE]
if not hits:
    sys.exit(0)

lines = [f"- {h['id']} ({h['type']}) — {h['title']}\n  {h['summary']}\n  file: {h['path']}"
         for h in hits]
context = ("<kb-auto-recall>\nPossibly relevant KB entries for this prompt "
           "(auto-recall, BM25 — judge relevance yourself; mention only if actually useful):\n"
           + "\n".join(lines) + "\n</kb-auto-recall>")
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": context,
    }
}))
PYEOF

exit 0

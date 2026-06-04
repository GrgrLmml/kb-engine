#!/bin/bash
# normalize-topics.sh — Claude Code SessionEnd hook for Gregor's KB.
#
# Sweeps the whole KB and canonicalizes topic tags against the controlled
# vocabulary (kb-data/_topics.yaml) by running audit-topics.py --fix in the
# background. This is the catch-all that normalizes entries no matter how they
# were created (/file-this OR hand-authored), complementing the in-flow
# normalization that the filing procedure already does.
#
# It rewrites ONLY `topics:` lines and is idempotent, so re-running is safe and
# usually a no-op. Fire-and-forget so the terminal does not hang on exit.
#
# Disable hatch: `touch kb-data/.no-normalize` to pause without editing settings.

set -u

# Resolve paths: prefer env (set by install into settings.json), else derive from
# this script's location (hooks/ -> repo root -> kb-data). `:=` assigns if unset.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${KB_ENGINE_DIR:=$(dirname "$SCRIPT_DIR")}"
: "${KB_DATA_DIR:=$KB_ENGINE_DIR/kb-data}"

AUDIT="$KB_ENGINE_DIR/scripts/audit-topics.py"
KB_DATA="$KB_DATA_DIR"
LOG_DIR="$KB_DATA/.librarian/log"

# Hook failures must never block session exit.
trap 'exit 0' EXIT

# Drain stdin (the SessionEnd JSON payload) so the harness does not block; we do
# not need it — this sweep is tree-wide, not session-specific.
while IFS= read -t 5 -r _line; do :; done 2>/dev/null || true

# Quick disable hatch.
[ -f "$KB_DATA/.no-normalize" ] && exit 0
[ -x "$AUDIT" ] || exit 0

mkdir -p "$LOG_DIR" 2>/dev/null || true
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
LOG="$LOG_DIR/${STAMP}-normalize.md"

# Prefer uv (the script declares its own deps via PEP 723 inline metadata);
# fall back to direct execution via the script's shebang.
if command -v uv >/dev/null 2>&1; then
  RUNNER=(uv run "$AUDIT" --fix)
else
  RUNNER=("$AUDIT" --fix)
fi

nohup bash -c '{ echo "# topic normalization — '"$STAMP"'"; echo; "$@"; } > "'"$LOG"'" 2>&1' _ "${RUNNER[@]}" \
  </dev/null >/dev/null 2>&1 &
disown

exit 0

#!/usr/bin/env bash
# install.sh — set up the KB system (kb-engine) for the current user.
#
# Global install: symlinks the slash commands into ~/.claude/commands, writes
# KB_ENGINE_DIR / KB_DATA_DIR into ~/.claude/settings.json (so commands,
# scripts, and hooks resolve their paths), registers the SessionEnd
# topic-normalization hook, bootstraps an empty kb-data, and installs the
# git pre-commit validator.
#
# Usage:
#   ./install.sh [--kb-data PATH] [--yes] [--uninstall]
#
#   --kb-data PATH   Where your KB content lives (default: <repo>/kb-data).
#   --yes            Don't prompt before editing ~/.claude/settings.json.
#   --uninstall      Remove command symlinks, the hook, env vars, pre-commit.
#
# Re-runnable (idempotent). Never touches your KB *content*, only wiring.

set -euo pipefail

KB_ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
CMD_DIR="$CLAUDE_DIR/commands"
HOOK="$KB_ENGINE_DIR/hooks/normalize-topics.sh"

KB_DATA_DIR="$KB_ENGINE_DIR/kb-data"
ASSUME_YES=0
UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --kb-data) KB_DATA_DIR="$2"; shift 2 ;;
    --kb-data=*) KB_DATA_DIR="${1#*=}"; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
# Normalize to absolute (without requiring the dir to exist yet).
KB_DATA_DIR="$(cd "$(dirname "$KB_DATA_DIR")" 2>/dev/null && pwd)/$(basename "$KB_DATA_DIR")" 2>/dev/null || KB_DATA_DIR="$KB_DATA_DIR"

say() { printf '  %s\n' "$*"; }
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$*"; }

PY="$(command -v python3 || true)"

# --- uninstall -----------------------------------------------------------
if [ "$UNINSTALL" = 1 ]; then
  echo "Uninstalling KB wiring (your kb-data content is left untouched)…"
  if [ -d "$CMD_DIR" ]; then
    for src in "$KB_ENGINE_DIR"/commands/*.md; do
      link="$CMD_DIR/$(basename "$src")"
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$src" ]; then rm -f "$link"; ok "removed command $(basename "$src")"; fi
    done
  fi
  if [ -f "$SETTINGS" ] && [ -n "$PY" ]; then
    "$PY" - "$SETTINGS" "$HOOK" <<'PYEOF'
import json, sys
p, hook = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d.get("env", {}).pop("KB_ENGINE_DIR", None)
d.get("env", {}).pop("KB_DATA_DIR", None)
se = d.get("hooks", {}).get("SessionEnd", [])
for grp in se:
    grp["hooks"] = [h for h in grp.get("hooks", []) if h.get("command") != hook]
d.get("hooks", {})["SessionEnd"] = [g for g in se if g.get("hooks")]
if not d.get("hooks", {}).get("SessionEnd"): d.get("hooks", {}).pop("SessionEnd", None)
if d.get("hooks") == {}: d.pop("hooks", None)
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
PYEOF
    ok "removed env vars + SessionEnd hook from settings.json"
  fi
  pc="$KB_DATA_DIR/.git/hooks/pre-commit"
  if [ -L "$pc" ]; then rm -f "$pc"; ok "removed pre-commit hook"; fi
  echo "Done."
  exit 0
fi

echo "Installing the KB system…"
say "kb-engine: $KB_ENGINE_DIR"
say "kb-data:      $KB_DATA_DIR"
echo

# --- 1. preflight --------------------------------------------------------
echo "1. Checking dependencies…"
miss=0
need() {
  if command -v "$1" >/dev/null 2>&1; then ok "$1"; else warn "$1 missing — $2"; miss=1; fi
}
need git  "install via your package manager (brew install git / apt install git)"
need uv   "install: curl -LsSf https://astral.sh/uv/install.sh | sh   (runs the Python scripts)"
[ -n "$PY" ] && ok "python3" || { warn "python3 missing — needed to edit settings.json safely"; miss=1; }
command -v jq >/dev/null 2>&1 && ok "jq (optional)" || warn "jq missing (optional — only the legacy auto-file hook uses it)"
if [ "$miss" = 1 ]; then echo; echo "Install the missing required tools above, then re-run ./install.sh"; exit 1; fi
echo

# --- 2. bootstrap kb-data ------------------------------------------------
echo "2. KB data…"
if [ ! -e "$KB_DATA_DIR/_route.md" ]; then
  mkdir -p "$KB_DATA_DIR"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat > "$KB_DATA_DIR/_route.md" <<EOF
---
type: route
folder: kb:/
title: Knowledge base — root
purpose: Top-level index of this knowledge base. Everything filed lands somewhere in the subtree below.
last_indexed: $now
topics: []
subroutes: []
entries: []
related: []
---

# Knowledge base — root

Empty on day one. Filing (/file-this) populates subroutes and entries over time.
See \$KB_ENGINE_DIR/docs/schema.md for the structure.
EOF
  ok "created root _route.md"
else
  ok "kb-data already initialized"
fi
if [ ! -e "$KB_DATA_DIR/_topics.yaml" ]; then
  cp "$KB_ENGINE_DIR/templates/_topics.yaml.template" "$KB_DATA_DIR/_topics.yaml"
  ok "created starter _topics.yaml (customize it)"
else
  ok "_topics.yaml already present"
fi
if [ ! -d "$KB_DATA_DIR/.git" ]; then
  ( cd "$KB_DATA_DIR" && git init -q ) && ok "git-initialized kb-data" || warn "could not git init kb-data"
fi
echo

# --- 3. command symlinks -------------------------------------------------
echo "3. Slash commands → $CMD_DIR …"
mkdir -p "$CMD_DIR"
n=0
for src in "$KB_ENGINE_DIR"/commands/*.md; do
  ln -sf "$src" "$CMD_DIR/$(basename "$src")"; n=$((n+1))
done
ok "linked $n commands"
echo

# --- 4. settings.json (env + hook) ---------------------------------------
echo "4. ~/.claude/settings.json (env vars + SessionEnd hook)…"
if [ -z "$PY" ]; then warn "python3 unavailable — skipping settings edit; set KB_ENGINE_DIR/KB_DATA_DIR yourself"; else
  do_it=1
  if [ "$ASSUME_YES" != 1 ]; then
    if [ -t 0 ]; then
      say "Will set env.KB_ENGINE_DIR, env.KB_DATA_DIR and register the SessionEnd"
      say "topic-normalization hook in $SETTINGS (existing keys preserved)."
      printf "  Proceed? [y/N] "; read -r ans; [ "$ans" = y ] || [ "$ans" = Y ] || do_it=0
    else
      do_it=0; warn "non-interactive and no --yes; skipping settings edit (re-run with --yes)"
    fi
  fi
  if [ "$do_it" = 1 ]; then
    mkdir -p "$CLAUDE_DIR"; [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
    "$PY" - "$SETTINGS" "$KB_ENGINE_DIR" "$KB_DATA_DIR" "$HOOK" <<'PYEOF'
import json, sys
p, mech, data, hook = sys.argv[1:5]
d = json.load(open(p))
d.setdefault("env", {})["KB_ENGINE_DIR"] = mech
d["env"]["KB_DATA_DIR"] = data
hooks = d.setdefault("hooks", {})
se = hooks.setdefault("SessionEnd", [])
present = any(h.get("command") == hook for g in se for h in g.get("hooks", []))
if not present:
    se.append({"hooks": [{"type": "command", "command": hook, "async": True, "timeout": 30}]})
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
PYEOF
    ok "settings.json updated"
  fi
fi
echo

# --- 5. pre-commit validator --------------------------------------------
echo "5. git pre-commit validator…"
if [ -d "$KB_DATA_DIR/.git" ]; then
  ln -sf "$KB_ENGINE_DIR/hooks/pre-commit" "$KB_DATA_DIR/.git/hooks/pre-commit"
  ok "installed pre-commit in kb-data"
else
  warn "kb-data is not a git repo — skipped pre-commit"
fi
echo

echo "Done. Open a new Claude Code session (or run /hooks to reload) and try: /load-kb"

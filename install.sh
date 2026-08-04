#!/usr/bin/env bash
# install.sh — set up the KB system (kb-engine) for the current user.
#
# Global install: symlinks the slash commands into ~/.claude/commands, writes
# KB_ENGINE_DIR / KB_DATA_DIR into ~/.claude/settings.json (so commands,
# scripts, and hooks resolve their paths), registers the SessionStart
# ambient-index hook, installs the nightly librarian launchd agent (validate +
# autosave + sync + doctor delta + problems scan + digest), bootstraps an
# empty kb-data, and installs the git pre-commit validator.
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
SKILL_DIR="$CLAUDE_DIR/skills"
AGENT_DIR="$CLAUDE_DIR/agents"
HOOK="$KB_ENGINE_DIR/hooks/normalize-topics.sh"
START_HOOK="$KB_ENGINE_DIR/hooks/session-start.sh"
ALLOW_HOOK="$KB_ENGINE_DIR/hooks/allow-kb-query.sh"
RECALL_HOOK="$KB_ENGINE_DIR/hooks/auto-recall.sh"
CAPTURE_HOOK="$KB_ENGINE_DIR/hooks/capture-candidate.sh"

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
  for sk in "$KB_ENGINE_DIR"/skills/*/; do
    name="$(basename "$sk")"
    link="$SKILL_DIR/$name"
    if [ -L "$link" ]; then rm -f "$link"; ok "removed skill $name"; fi
  done
  if [ -d "$AGENT_DIR" ]; then
    for src in "$KB_ENGINE_DIR"/agents/*.md; do
      [ -e "$src" ] || continue
      link="$AGENT_DIR/$(basename "$src")"
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$src" ]; then rm -f "$link"; ok "removed agent $(basename "$src")"; fi
    done
  fi
  if [ -f "$SETTINGS" ] && [ -n "$PY" ]; then
    "$PY" - "$SETTINGS" "$KB_ENGINE_DIR" "$KB_DATA_DIR" "$HOOK" "$START_HOOK" "$ALLOW_HOOK" "$RECALL_HOOK" "$CAPTURE_HOOK" <<'PYEOF'
import json, sys
p, mech, data, *ours = sys.argv[1:]
d = json.load(open(p))
d.get("env", {}).pop("KB_ENGINE_DIR", None)
d.get("env", {}).pop("KB_DATA_DIR", None)
if d.get("env") == {}: d.pop("env", None)
hooks = d.get("hooks", {})
for event in ("SessionEnd", "SessionStart", "UserPromptSubmit", "PreToolUse"):
    groups = hooks.get(event, [])
    for grp in groups:
        grp["hooks"] = [h for h in grp.get("hooks", []) if h.get("command") not in ours]
    hooks[event] = [g for g in groups if g.get("hooks")]
    if not hooks[event]: hooks.pop(event, None)
if d.get("hooks") == {}: d.pop("hooks", None)
perms = d.get("permissions", {})
kb_rules = {
    f"Bash({mech}/scripts/kb:*)",
    "Bash($KB_ENGINE_DIR/scripts/kb:*)",
    'Bash("$KB_ENGINE_DIR"/scripts/kb:*)',
    f"Bash({mech}/scripts/validate.py:*)",
    "Bash($KB_ENGINE_DIR/scripts/validate.py:*)",
    f"Bash({mech}/scripts/audit-topics.py:*)",
    "Bash($KB_ENGINE_DIR/scripts/audit-topics.py:*)",
}
if "allow" in perms:
    perms["allow"] = [r for r in perms["allow"] if r not in kb_rules]
    if not perms["allow"]: perms.pop("allow")
if "additionalDirectories" in perms:
    perms["additionalDirectories"] = [x for x in perms["additionalDirectories"] if x != data]
    if not perms["additionalDirectories"]: perms.pop("additionalDirectories")
if d.get("permissions") == {}: d.pop("permissions", None)
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
PYEOF
    ok "removed env vars, KB hooks + KB permission rules from settings.json"
  fi
  pc="$KB_DATA_DIR/.git/hooks/pre-commit"
  if [ -L "$pc" ]; then rm -f "$pc"; ok "removed pre-commit hook"; fi
  pcl="$KB_ENGINE_DIR/.git/hooks/pre-commit"
  if [ -L "$pcl" ]; then rm -f "$pcl"; ok "removed engine pre-commit leak guard"; fi
  plist="$HOME/Library/LaunchAgents/com.kb-engine.librarian-nightly.plist"
  if [ -f "$plist" ]; then
    launchctl unload "$plist" 2>/dev/null || true
    rm -f "$plist"; ok "removed nightly librarian launchd agent"
  fi
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
GI="$KB_DATA_DIR/.gitignore"
touch "$GI"
for line in ".DS_Store" ".librarian.lock" ".librarian/log/" ".index/"; do
  grep -qxF "$line" "$GI" || echo "$line" >> "$GI"
done
ok ".gitignore covers runtime artifacts (.index/, .librarian/)"
echo

# --- 3. command + skill symlinks ------------------------------------------
echo "3. Slash commands → $CMD_DIR …"
mkdir -p "$CMD_DIR"
n=0
for src in "$KB_ENGINE_DIR"/commands/*.md; do
  ln -sf "$src" "$CMD_DIR/$(basename "$src")"; n=$((n+1))
done
ok "linked $n commands"
mkdir -p "$SKILL_DIR"
for sk in "$KB_ENGINE_DIR"/skills/*/; do
  name="$(basename "$sk")"
  ln -sfn "${sk%/}" "$SKILL_DIR/$name"
  ok "linked skill $name"
done
mkdir -p "$AGENT_DIR"
for src in "$KB_ENGINE_DIR"/agents/*.md; do
  [ -e "$src" ] || continue
  ln -sf "$src" "$AGENT_DIR/$(basename "$src")"
  ok "linked agent $(basename "$src" .md)"
done
echo

# --- 4. settings.json (env + hooks) ---------------------------------------
echo "4. ~/.claude/settings.json (env vars + SessionEnd/SessionStart hooks)…"
if [ -z "$PY" ]; then warn "python3 unavailable — skipping settings edit; set KB_ENGINE_DIR/KB_DATA_DIR yourself"; else
  do_it=1
  if [ "$ASSUME_YES" != 1 ]; then
    if [ -t 0 ]; then
      say "Will set env.KB_ENGINE_DIR, env.KB_DATA_DIR, register the"
      say "SessionStart ambient-index hook (removing any stale SessionEnd"
      say "normalize hook), the PreToolUse permission hook (auto-allows"
      say "read-only kb queries), AND"
      say "permission allow rules for the kb scripts + kb-data as an additional"
      say "working directory in $SETTINGS (existing keys preserved)."
      printf "  Proceed? [y/N] "; read -r ans; [ "$ans" = y ] || [ "$ans" = Y ] || do_it=0
    else
      do_it=0; warn "non-interactive and no --yes; skipping settings edit (re-run with --yes)"
    fi
  fi
  if [ "$do_it" = 1 ]; then
    mkdir -p "$CLAUDE_DIR"; [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
    "$PY" - "$SETTINGS" "$KB_ENGINE_DIR" "$KB_DATA_DIR" "$HOOK" "$START_HOOK" "$ALLOW_HOOK" "$RECALL_HOOK" "$CAPTURE_HOOK" <<'PYEOF'
import json, sys
p, mech, data, hook, start_hook, allow_hook, recall_hook, capture_hook = sys.argv[1:9]
d = json.load(open(p))
d.setdefault("env", {})["KB_ENGINE_DIR"] = mech
d["env"]["KB_DATA_DIR"] = data
hooks = d.setdefault("hooks", {})
# The per-session SessionEnd normalize hook is retired: nightly `kb sync` (via
# scripts/librarian-nightly) does the same work once a day. Drop a stale
# registration if a previous install left one behind.
se = hooks.get("SessionEnd", [])
for grp in se:
    grp["hooks"] = [h for h in grp.get("hooks", []) if h.get("command") != hook]
hooks["SessionEnd"] = [g for g in se if g.get("hooks")]
if not hooks["SessionEnd"]:
    hooks.pop("SessionEnd", None)
ss = hooks.setdefault("SessionStart", [])
if not any(h.get("command") == start_hook for g in ss for h in g.get("hooks", [])):
    # matcher: only fresh contexts — a resumed session already has the index
    ss.append({"matcher": "startup|clear",
               "hooks": [{"type": "command", "command": start_hook, "timeout": 30}]})
pt = hooks.setdefault("PreToolUse", [])
if not any(h.get("command") == allow_hook for g in pt for h in g.get("hooks", [])):
    # auto-allow read-only kb queries — plain allow rules can't match commands
    # containing $KB_ENGINE_DIR (the expansion heuristic forces a prompt)
    pt.append({"matcher": "Bash",
               "hooks": [{"type": "command", "command": allow_hook, "timeout": 10}]})
ups = hooks.setdefault("UserPromptSubmit", [])
if not any(h.get("command") == recall_hook for g in ups for h in g.get("hooks", [])):
    # semantic auto-recall — registration gated on `kb eval --recall` showing
    # zero false-fires on the no-hit calibration set
    ups.append({"hooks": [{"type": "command", "command": recall_hook, "timeout": 15}]})
se2 = hooks.setdefault("SessionEnd", [])
if not any(h.get("command") == capture_hook for g in se2 for h in g.get("hooks", [])):
    # capture-candidate queue (deterministic, no LLM) — feeds UNFILED SESSIONS
    se2.append({"hooks": [{"type": "command", "command": capture_hook,
                           "async": True, "timeout": 15}]})
perms = d.setdefault("permissions", {})
allow = perms.setdefault("allow", [])
for rule in (
    f"Bash({mech}/scripts/kb:*)",
    "Bash($KB_ENGINE_DIR/scripts/kb:*)",
    'Bash("$KB_ENGINE_DIR"/scripts/kb:*)',
    f"Bash({mech}/scripts/validate.py:*)",
    "Bash($KB_ENGINE_DIR/scripts/validate.py:*)",
    f"Bash({mech}/scripts/audit-topics.py:*)",
    "Bash($KB_ENGINE_DIR/scripts/audit-topics.py:*)",
):
    if rule not in allow:
        allow.append(rule)
dirs = perms.setdefault("additionalDirectories", [])
if data not in dirs:
    dirs.append(data)
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
# Leak guard on the ENGINE repo: block commits containing terms from the
# private $KB_DATA_DIR/_banned-terms.txt (the list never ships with the repo).
if [ -d "$KB_ENGINE_DIR/.git" ]; then
  ln -sf "$KB_ENGINE_DIR/hooks/pre-commit-no-leaks" "$KB_ENGINE_DIR/.git/hooks/pre-commit"
  ok "installed pre-commit leak guard in kb-engine"
  [ -f "$KB_DATA_DIR/_banned-terms.txt" ] || \
    warn "no $KB_DATA_DIR/_banned-terms.txt yet — leak guard is a no-op until you create it"
fi
echo

# --- 6. nightly librarian (launchd, macOS only) ---------------------------
echo "6. Nightly librarian…"
PLIST_LABEL="com.kb-engine.librarian-nightly"
PLIST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
if [ "$(uname)" = "Darwin" ]; then
  do_plist=1
  if [ "$ASSUME_YES" != 1 ]; then
    if [ -t 0 ]; then
      say "Will install a launchd agent that runs scripts/librarian-nightly at"
      say "03:30 daily: validates, auto-commits kb-data, kb sync, doctor delta,"
      say "problems scan, log rotation, digest — plus one weekly headless"
      say "criticize pass (WIP-gated) and monthly dedup/mine-recipes."
      printf "  Install nightly agent? [y/N] "; read -r ans; [ "$ans" = y ] || [ "$ans" = Y ] || do_plist=0
    else
      do_plist=0; warn "non-interactive and no --yes; skipping nightly agent"
    fi
  fi
  if [ "$do_plist" = 1 ]; then
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$PLIST_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$KB_ENGINE_DIR/scripts/librarian-nightly</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>KB_ENGINE_DIR</key><string>$KB_ENGINE_DIR</string>
    <key>KB_DATA_DIR</key><string>$KB_DATA_DIR</string>
    <key>PATH</key><string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>3</integer><key>Minute</key><integer>30</integer></dict>
  <key>StandardOutPath</key><string>$KB_DATA_DIR/.librarian/nightly.out</string>
  <key>StandardErrorPath</key><string>$KB_DATA_DIR/.librarian/nightly.err</string>
</dict>
</plist>
EOF
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST" 2>/dev/null && ok "nightly agent loaded ($PLIST_LABEL, 03:30)" \
      || warn "wrote $PLIST but launchctl load failed — load it manually"
  fi
else
  warn "not macOS — schedule scripts/librarian-nightly via cron yourself (e.g. 30 3 * * *)"
fi
echo

# --- 7. search index ------------------------------------------------------
echo "7. Search index…"
if KB_DATA_DIR="$KB_DATA_DIR" "$KB_ENGINE_DIR/scripts/kb" index 2>/dev/null; then
  ok "FTS index built ($KB_DATA_DIR/.index/kb.db)"
else
  warn "index build failed — it will self-build on first 'kb search'"
fi
echo

echo "Done. Open a new Claude Code session (or run /hooks to reload) and try: /find <something>"
echo "The compact KB index is now injected into every new session (pause: touch \$KB_DATA_DIR/.no-ambient)."

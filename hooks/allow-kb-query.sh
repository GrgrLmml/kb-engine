#!/bin/bash
# PreToolUse(Bash) permission hook: auto-allow KB engine commands + read-only KB access.
#
# Why this exists: Claude Code's permission matcher refuses to prefix-match
# commands containing variable expansion ($KB_ENGINE_DIR, $KB_DATA_DIR), so
# plain allow rules in settings.json never fire for them ("Contains
# simple_expansion" prompt). This hook explicitly allows a command when every
# segment is either:
#   - a KB engine script (scripts/kb, validate.py, audit-topics.py — these
#     only operate within kb-data, which has blanket Write permission), or
#   - a read-only file command (cat/sed -n/grep/find/echo/date/...) whose only
#     variable expansions are $KB_ENGINE_DIR/$KB_DATA_DIR and which writes
#     nothing.
# Anything else falls through to the normal permission flow.

set -euo pipefail

ENGINE="${KB_ENGINE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

is_kb_engine_cmd() {
  local seg="$1" rest=""
  case "$seg" in
    "\$KB_ENGINE_DIR/scripts/"*)     rest="${seg#\$KB_ENGINE_DIR/scripts/}" ;;
    "\"\$KB_ENGINE_DIR\"/scripts/"*) rest="${seg#\"\$KB_ENGINE_DIR\"/scripts/}" ;;
    "$ENGINE/scripts/"*)             rest="${seg#"$ENGINE"/scripts/}" ;;
    *) return 1 ;;
  esac
  case "$rest" in
    kb|kb\ *)                             return 0 ;;
    validate.py|validate.py\ *)           return 0 ;;
    audit-topics.py|audit-topics.py\ *)   return 0 ;;
    *) return 1 ;;
  esac
}

is_readonly_cmd() {
  local seg="$1"

  # only the two trusted KB vars may be expanded
  local stripped="${seg//\$\{KB_DATA_DIR\}/}"
  stripped="${stripped//\$\{KB_ENGINE_DIR\}/}"
  stripped="${stripped//\$KB_DATA_DIR/}"
  stripped="${stripped//\$KB_ENGINE_DIR/}"
  case "$stripped" in *'$'*) return 1 ;; esac

  # no output redirection (harmless /dev/null sinks were stripped globally)
  case "$seg" in *'>'*) return 1 ;; esac

  # shellcheck disable=SC2086
  set -- $seg
  case "${1:-}" in
    cat|head|tail|wc|ls|stat|file|tree|sort|uniq|diff|cut|column|comm|\
    basename|dirname|realpath|grep|rg|jq|yq|\
    echo|printf|pwd|which|true|false|test|\[)
      return 0 ;;
    date)
      case " $seg" in *" -s"*|*" --set"*) return 1 ;; esac
      return 0 ;;
    sed)
      case " $seg" in *" -i"*) return 1 ;; esac
      return 0 ;;
    find)
      case "$seg" in *-delete*|*-exec*|*-execdir*|*-ok*) return 1 ;; esac
      return 0 ;;
    *) return 1 ;;
  esac
}

# Neutralize harmless redirections before splitting, so `2>/dev/null` and
# `2>&1` don't trip the splitter or the redirection check.
cmd="${cmd//2>\/dev\/null/ }"
cmd="${cmd//&>\/dev\/null/ }"
cmd="${cmd//>\/dev\/null/ }"
cmd="${cmd//2>&1/ }"

# Split on command separators (; | & and newlines); every non-empty segment
# must be a KB engine command or read-only access, otherwise stay out of the
# decision.
while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"  # ltrim
  seg="${seg%"${seg##*[![:space:]]}"}"  # rtrim
  [ -z "$seg" ] && continue
  # never decide on command substitution / backticks
  case "$seg" in *'$('*|*'`'*) exit 0 ;; esac
  is_kb_engine_cmd "$seg" || is_readonly_cmd "$seg" || exit 0
done < <(printf '%s\n' "$cmd" | tr ';|&' '\n')

echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"KB engine command / read-only KB access — always allowed"}}'

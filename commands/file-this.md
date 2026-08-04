---
description: File the current conversation into Gregor's KB
argument-hint: [--bg] [optional one-line hint about where it belongs]
---

You are filing the **current conversation** into Gregor's knowledge base.

User's optional hint about placement (may start with `--bg`): $ARGUMENTS

**Background mode** — if the arguments start with `--bg`, do NOT file inline. Instead:

1. Locate the current session's transcript: the newest `*.jsonl` under
   `~/.claude/projects/<cwd-with-slashes-replaced-by-dashes>/` (the same artifact
   the SessionEnd hooks consume).
2. Fire and forget:
   ```sh
   nohup "$KB_ENGINE_DIR/scripts/librarian" file --transcript <path> --hint "<rest of the arguments>" >/dev/null 2>&1 &
   ```
3. Confirm in ONE line ("filing in background — log lands in `$KB_DATA_DIR/.librarian/log/`") and stop.
   Caveat to keep in mind: the background pass sees the transcript as of now, not anything after this message.

**Inline mode** (no `--bg`) — the conversation is already loaded in your context; do not ask the user to re-summarize. Read `$KB_ENGINE_DIR/librarian/procedure-file.md` and follow it exactly. The hint above (if any) goes into step 2's placement decision.

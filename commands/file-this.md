---
description: File the current conversation into Gregor's KB
argument-hint: [--bg] [optional one-line hint about where it belongs]
---

You are filing the **current conversation** into Gregor's knowledge base.

User's optional hint about placement (may start with `--bg`): $ARGUMENTS

**Background mode** — if the arguments start with `--bg`, do NOT file inline. Instead:

1. Fire and forget (the hook has recorded this session's transcript path; the librarian resolves it):
   ```sh
   nohup "$KB_ENGINE_DIR/scripts/librarian" file --session auto --cwd "$PWD" --hint "<rest of the arguments>" >/dev/null 2>&1 &
   ```
2. Confirm in ONE line ("filing in background — log lands in `$KB_DATA_DIR/.librarian/log/`") and stop.
   Caveat: the background pass sees the transcript as of now, not anything after this message.

**Inline mode** (no `--bg`) — the conversation is already in your context; do not ask the user to re-summarize. Read `$KB_ENGINE_DIR/librarian/procedure-file.md` and follow it. You distill; `kb file` writes. The hint above (if any) steers the `folder` you choose.

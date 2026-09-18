---
description: Capture a small durable fact into Gregor's KB in seconds (no transcript)
argument-hint: <the fact — e.g. "the staging vector DB lives in the staging-2 cluster, namespace search">
---

You are capturing a **jot** — a small, durable fact — into Gregor's knowledge base: **$ARGUMENTS**

If $ARGUMENTS is empty, output: "Usage: `/jot <fact worth remembering>`." Then stop.

A jot is a normal leaf, minimal: the fact IS the summary, the body is the fact plus any context Gregor gave. Half the value of a KB is exactly these facts — they must not cost a ceremony. **One tool call.**

## Procedure

1. **Place it** from the ambient `<kb-ambient-index>` folder map already in context (only if nothing fits at all, run `$KB_ENGINE_DIR/scripts/kb routes --compact`; a genuinely new folder needs a `folder_purpose` sentence — it is hand-curated forever).

2. **Write it** — one command, JSON on stdin, `kb file` does ids, timestamps, YAML, validation, route bookkeeping and index refresh:
   ```sh
   "$KB_ENGINE_DIR/scripts/kb" file --jot --meta - <<'JSON'
   {"title": "<the fact, ≤70 chars>",
    "folder": "kb:/<existing folder>",
    "topics": ["<2-4 tags, canonical forms from _topics.yaml where you know them>"],
    "summary": "<the fact itself, self-contained, 1-3 sentences>",
    "body": "<the fact again plus any context/link/caveat Gregor gave>",
    "sources": ["<https:// links Gregor gave, if any>"],
    "claims": [{"subject": "<area>.<thing>.<attribute>", "value": "<the value>", "since": "<YYYY-MM-DD if known>", "kind": "observed"}],
    "decisions": [], "open_questions": [], "participants": ["gregor"]}
   JSON
   ```
   A jot is almost always a **claim** (a current-state fact with a key) — include it so the engine can track when it changes. Reuse an existing subject (`kb subjects --match "<words>"`) before minting one; omit `claims` only for facts with no "current value" (history, a one-off number).
   ```
   ```
   `kb file` prints `FILED <path>` or `REFUSED` with the schema errors (fix the payload, re-run — nothing was written).

3. **Confirm in one line:** `Jotted <id> → <path>`. Nothing else.

## Constraints

- One fact per jot. Two unrelated facts → two `kb file` calls.
- Don't pad the summary — a jot reader wants the fact, not prose.
- No `git commit`.

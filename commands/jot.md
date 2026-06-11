---
description: Capture a small durable fact into Gregor's KB in seconds (no transcript)
argument-hint: <the fact — e.g. "staging Qdrant lives in the staging-2 GKE cluster, namespace vdb">
---

You are capturing a **jot** — a small, durable fact — into Gregor's knowledge base: **$ARGUMENTS**

If $ARGUMENTS is empty, output: "Usage: `/jot <fact worth remembering>`." Then stop.

**KB root:** `$KB_DATA_DIR` · **CLI:** `$KB_ENGINE_DIR/scripts/kb` · **Schema:** `$KB_ENGINE_DIR/docs/schema.md`

A jot is a normal leaf entry, just minimal: full frontmatter, a 2–5 line body instead of a transcript. Half the value of a KB is exactly these facts — they must not require a full `/file-this` ceremony.

## Procedure (keep this under ~30 seconds of work)

1. **Place it.** Pick the folder from the ambient `<kb-ambient-index>` if it's in context, else run `$KB_ENGINE_DIR/scripts/kb routes --compact`. Use the existing folder that best fits; only create a new folder if nothing fits at all (then its `_route.md` needs a hand-written `purpose` — see the template).

2. **Write the leaf.** Filename `<YYYY-MM-DD>-<slug>.md` (today UTC, slug from the fact). Standard entry frontmatter, all keys present:
   - `title`: the fact, compressed to ≤ 70 chars.
   - `topics`: 2–4 tags, normalized against `$KB_DATA_DIR/_topics.yaml`.
   - `summary`: the fact itself, self-contained (1–3 sentences). This IS the payload.
   - `decisions`/`open_questions`: usually `[]`; `recipe_candidate: false`.
   - Body below the frontmatter: the fact again, plus any context Gregor gave (a link, a caveat). No transcript.

3. **Sync:** `$KB_ENGINE_DIR/scripts/kb sync --quiet`

4. **Confirm in one line:** `Jotted <id> → <path>`. Nothing else.

## Constraints

- One fact per jot. If Gregor gave two unrelated facts, write two leaves (still one sync).
- Don't pad the summary — a jot reader wants the fact, not prose.
- Quote YAML strings containing `: ` or `#`.
- No `git commit`.

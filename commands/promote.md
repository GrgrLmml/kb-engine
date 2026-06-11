---
description: Load a KB entry's full transcript into the main session (HOT tier)
argument-hint: <entry-id | kb:/path | filesystem-path>
---

Promote a KB entry from WARM (summary only) to HOT (full transcript loaded into main context).

**Argument:** $ARGUMENTS

If $ARGUMENTS is empty, output: "Usage: `/promote <id-or-path>`. Examples: `/promote 2026-05-05-1to1-kostas-prep-decision-tiers` (bare id), `/promote kb:/people/kostas/2026-05-05-1to1-kostas-prep-decision-tiers.md`." Then stop.

## Procedure

1. **Resolve** the argument (bare id, `kb:/` URI, or filesystem path — the CLI handles all three):

   ```sh
   $KB_ENGINE_DIR/scripts/kb show --path "$ARGUMENTS"
   ```

   If it errors (no such id, ambiguous), surface the CLI's message verbatim and stop. Sanity check: the resolved path must not be a `_route.md` (folder indexes aren't promotable entries).

2. **`Read` the resolved file in full.** Then output a one-line confirmation:

   > Loaded `<id>` HOT (`<resolved-path>`). Ask follow-ups; the full transcript is in context.

That's it. No analysis, no summarization — Gregor will drive from here.

## Constraints

- Read-only operation. Do not modify the entry.
- Do not load multiple entries unless Gregor asks (`/promote` takes one argument).
- Do not also load related entries automatically — keep HOT tight; Gregor can `/promote` more on demand.

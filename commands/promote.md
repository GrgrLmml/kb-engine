---
description: Load a KB entry's full transcript into the main session (HOT tier)
argument-hint: <entry-id | kb:/path | filesystem-path>
---

Promote a KB entry from WARM (summary only) to HOT (full transcript loaded into main context).

**Argument:** $ARGUMENTS

If $ARGUMENTS is empty, output: "Usage: `/promote <id-or-path>`. Examples: `/promote 2026-05-05-1to1-kostas-prep-decision-tiers` (bare id), `/promote kb:/people/kostas/2026-05-05-1to1-kostas-prep-decision-tiers.md`, `/promote $KB_DATA_DIR/people/kostas/2026-05-05-1to1-kostas-prep-decision-tiers.md`." Then stop.

## Resolution

Resolve $ARGUMENTS to an absolute filesystem path:

1. **If it starts with `$KB_DATA_DIR/`** — use as-is.
2. **If it starts with `kb:/`** — strip the `kb:/` prefix and prepend `$KB_DATA_DIR/`. (Special case: `kb:/` alone resolves to the root, which doesn't have a leaf entry — error in that case.)
3. **Otherwise treat as a bare id** — grep `$KB_DATA_DIR/` for a file whose frontmatter contains `^id: <arg>$`. Use Bash:
   ```sh
   grep -rln --include='*.md' "^id: ${ARGUMENT}$" $KB_DATA_DIR/
   ```
   - If exactly one hit: use that path.
   - If zero hits: output `No entry with id '<arg>' found in the KB.` and stop.
   - If multiple hits: output the list and ask Gregor to disambiguate by full path. Stop.

Sanity check: the resolved path must exist, end with `.md`, and not be a `_route.md` (those are folder indexes, not promotable entries). If any check fails, surface a clear error and stop.

## Action

`Read` the resolved file in full. Then output a one-line confirmation:

> Loaded `<id>` HOT (`<resolved-path>`). Ask follow-ups; the full transcript is in context.

That's it. No analysis, no summarization — Gregor will drive from here.

## Constraints

- Read-only operation. Do not modify the entry.
- Do not load multiple entries unless Gregor asks (`/promote` takes one argument).
- Do not also load related entries automatically — keep HOT tight; Gregor can `/promote` more on demand.

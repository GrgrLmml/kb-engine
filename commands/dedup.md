---
description: Find duplicate / superseding entries within a subtree (or whole KB)
argument-hint: <kb:/folder> (use kb:/ for whole tree)
---

Find duplicate or superseding entries under **$ARGUMENTS**.

If $ARGUMENTS is empty or doesn't start with `kb:/`, output: "Usage: `/dedup kb:/folder` (or `/dedup kb:/` for the whole tree). Finds pairs of entries that cover the same ground and marks the older one as superseded; flags genuine contradictions in the newer entry's summary." Then stop.

## Procedure

Spawn an Agent subagent (general-purpose). Brief it:

> Read `$KB_ENGINE_DIR/librarian/procedure-dedup.md` and follow it for scope `$ARGUMENTS`.
>
> You have full file access. Update frontmatter (`status`, `supersedes`, `superseded_by`, `contradicts`, `summary` notes for contradictions, `updated:` timestamps). Update parent `_route.md` `entries[].summary` lines with a `[superseded]` prefix where applicable. Bump `last_indexed:` on touched routes.
>
> When done, run `$KB_ENGINE_DIR/scripts/validate.py` and confirm clean. Output the procedure's DONE summary.
>
> Conservative bias: if you're not confident two entries cover the same ground, leave them alone. False positives here corrupt the KB silently.
>
> If no high-confidence pairs found, output `SKIPPED: <reason>`. If LLM confidence is low on ≥30% of proposed pairs, output `ABORTED: <reason>` and don't write anything.

After the subagent returns, present its output verbatim. Add:

> Review with `git -C $KB_DATA_DIR status` and commit when ready. Revert with `git -C $KB_DATA_DIR restore .`.

## Constraints

- Never delete entries. Supersede, don't destroy.
- `supersedes` / `superseded_by` / `contradicts` use bare ids, never paths.
- Don't run `git commit`.

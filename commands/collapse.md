---
description: Collapse sparse subfolders back into their parent (inverse of /split)
argument-hint: <kb:/parent-folder>
---

Collapse sparse subfolders of **$ARGUMENTS** back into the parent.

If $ARGUMENTS is empty or doesn't start with `kb:/`, output: "Usage: `/collapse kb:/parent`. Looks at the parent's direct subfolders and merges any that no longer warrant their own existence (1 entry, fully-subsumed topic, etc.)." Then stop.

## Procedure

Spawn an Agent subagent (general-purpose) so the file I/O stays out of the main session. Brief it:

> Read `$KB_ENGINE_DIR/librarian/procedure-collapse.md` and follow it for parent folder `$ARGUMENTS`.
>
> You have full file access (Read, Write, Edit, Bash). Use `git mv` and `git rm` for moves and deletes so history is preserved.
>
> When done, run `$KB_ENGINE_DIR/scripts/validate.py` and confirm clean. Output the procedure's DONE summary.
>
> If preconditions fail, output `SKIPPED: <reason>`. If the proposed collapses would over-flatten, output `ABORTED: <reason>` and don't write anything.
>
> Conservative bias: when unsure whether a subfolder warrants keeping, KEEP it. Collapses are harder to reverse than non-collapses.

After the subagent returns, present its output verbatim. Add:

> Review with `git -C $KB_DATA_DIR status` and commit when ready. Revert with `git -C $KB_DATA_DIR restore .`.

## Constraints

- Subagent only — don't load entry transcripts in the main session.
- Don't run `git commit`.

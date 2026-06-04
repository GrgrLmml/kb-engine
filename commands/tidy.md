---
description: Run housekeeping passes (split + collapse + dedup) on a KB subtree
argument-hint: <kb:/folder> (use kb:/ for whole tree)
---

Run all housekeeping passes on **$ARGUMENTS** in sequence: split overgrown leaves, collapse sparse subfolders, dedup overlapping entries.

If $ARGUMENTS is empty or doesn't start with `kb:/`, output: "Usage: `/tidy kb:/folder` (or `/tidy kb:/` for whole tree)." Then stop.

## Procedure

Spawn one Agent subagent (general-purpose). Brief it:

> Run housekeeping passes for `$ARGUMENTS` in this order:
>
> 1. **Split overgrown leaves.** For every folder under `$ARGUMENTS` that has ≥5 direct entries, follow `$KB_ENGINE_DIR/librarian/procedure-split.md`. Apply the plan only if the procedure produces a non-`SKIPPED`/`ABORTED` result.
>
> 2. **Collapse sparse subfolders.** For every folder under `$ARGUMENTS` that has subroutes, follow `$KB_ENGINE_DIR/librarian/procedure-collapse.md`. Apply the plan only if non-`SKIPPED`/`ABORTED`.
>
> 3. **Dedup the subtree.** Follow `$KB_ENGINE_DIR/librarian/procedure-dedup.md` once for `$ARGUMENTS`. Apply if non-`SKIPPED`/`ABORTED`.
>
> Between each pass, run `$KB_ENGINE_DIR/scripts/validate.py`. If validation fails, stop and surface errors — do NOT continue to the next pass.
>
> When all passes finish (or one stops), output a summary table:
>
> ```
> ## Tidy summary for <kb-path>
>
> | Pass     | Outcome | Detail                                   |
> | -------- | ------- | ---------------------------------------- |
> | Split    | <done|skipped|aborted|errored> | <one-line> |
> | Collapse | <done|skipped|aborted|errored> | <one-line> |
> | Dedup    | <done|skipped|aborted|errored> | <one-line> |
>
> Validator: <clean | N errors>
> ```
>
> Conservative bias throughout: SKIP rather than ABORT, ABORT rather than apply a low-quality plan.

After the subagent returns, present its summary verbatim. Add:

> Review with `git -C $KB_DATA_DIR status` and commit when ready. Revert with `git -C $KB_DATA_DIR restore .`.

## Constraints

- Single subagent for all three passes — no need to spawn three separate ones; the procedure files contain the necessary detail.
- Each pass writes its own working-tree changes; `git status` will show the cumulative diff after `/tidy`.
- Don't run `git commit`. Gregor reviews and commits manually.

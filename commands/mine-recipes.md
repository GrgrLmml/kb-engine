---
description: Mine the KB for recurring procedures and propose them as draft recipes
argument-hint: <kb:/folder> (use kb:/ for whole tree; default whole tree)
---

Mine **$ARGUMENTS** for reusable procedures that aren't captured as recipes yet, and flag
recipes ready to graduate into skills.

If $ARGUMENTS is empty, default the scope to `kb:/` (whole tree). If it's non-empty but doesn't
start with `kb:/`, output: "Usage: `/mine-recipes kb:/folder` (or `/mine-recipes` for the whole tree)." and stop.

## Procedure

Spawn an Agent subagent (general-purpose). Brief it:

> Read `$KB_ENGINE_DIR/librarian/procedure-mine-recipes.md` and follow it for scope `<resolved scope>`.
>
> Stay on the summary layer in the survey (route frontmatter + leaf `summary` fields) — do NOT
> load transcripts to mine. Prioritize entries flagged `recipe_candidate: true`. Cross-check
> existing recipes under `kb:/recipes/` so you never re-propose what's already there.
>
> Mint NEW recipes as `status: draft` (via `procedure-extract-recipe.md`); REFINE existing ones
> in place; report skill-graduation candidates without writing skills. Run
> `$KB_ENGINE_DIR/scripts/validate.py` at the end and confirm clean.
>
> Conservative bias: a spurious recipe is worse than a missed one. SKIP rather than mint a
> shaky candidate; ABORT (write nothing) if you're unsure on ≥30% of candidates. Output the
> procedure's PLAN, then its DONE summary.

After the subagent returns, present its output verbatim. Add:

> These recipes are **drafts** — review and verify each procedure, then flip `status: draft → active`. Review with `git -C $KB_DATA_DIR status`; revert with `git -C $KB_DATA_DIR restore .`.

## Constraints

- New recipes are `status: draft` only. Never mint `active` from mining.
- Don't supersede/delete existing recipes here — propose, don't overwrite.
- Don't auto-generate skills — graduation is report-only.
- Don't run `git commit`. Gregor reviews and commits manually.

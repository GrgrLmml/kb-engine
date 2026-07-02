---
description: Mine the KB for explanatory models (falsifiable claims) and chain them into derived conclusions — the deduction layer
argument-hint: <kb:/folder> (use kb:/ for whole tree; default whole tree)
---

Theorize over **$ARGUMENTS**: propose `type: model` entries (falsifiable claims that explain several episodes) and chain existing model statements into derived conclusions. Induction finds patterns in what happened; this pass writes down the *premises* and deduces what they jointly entail.

If $ARGUMENTS is empty, default the scope to `kb:/` (whole tree). If it's non-empty but doesn't start with `kb:/`, output: "Usage: `/theorize kb:/folder` (or `/theorize` for the whole tree)." and stop.

## Procedure

Spawn an Agent subagent (general-purpose). Brief it:

> Read `$KB_ENGINE_DIR/librarian/procedure-theorize.md` and follow it for scope `<resolved scope>`.
>
> Stay on the summary layer in the survey — do NOT load transcripts to mine; read one only to get a statement right just before writing. Read all of `kb:/models/` first so you refine instead of duplicating, and so existing statements are available as premises for the deduction step.
>
> Mint NEW models as `status: hypothesis` under `kb:/models/` (bootstrap that folder + `_route.md` if absent). One falsifiable statement per model; 1–3 checkable predictions each; `derived_from` set; `evidence_for` EMPTY (grounding is not confirmation). Chain premises into derivations — every derivation cites all its premise ids and inherits the weakest premise's status. Flag premise contradictions; they are findings, not failures. Run `$KB_ENGINE_DIR/scripts/kb sync` then `$KB_ENGINE_DIR/scripts/validate.py` at the end and confirm clean.
>
> Conservative bias: a wrong premise poisons every chain through it. SKIP shaky candidates; ABORT (write nothing) if unsure on ≥30%. Output the procedure's PLAN, then its DONE summary.

After the subagent returns, present its output verbatim. Add:

> These models are **hypotheses** — review each statement; predictions get tested automatically as future episodes are filed. Review with `git -C $KB_DATA_DIR status`; revert with `git -C $KB_DATA_DIR restore .`.

## Constraints

- New models are `status: hypothesis` only. Validation comes from later episodes, never from this pass.
- Don't supersede/delete existing models here — supersession is proposed explicitly in the plan.
- Derived conclusions must always carry their premise chain (`[derived: id + id]`) — an unchained conclusion is an opinion, not a deduction.
- Don't run `git commit`. Gregor reviews and commits manually.

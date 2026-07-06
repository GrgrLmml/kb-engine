---
description: Attack the KB's theory layer — hard-to-vary checks, rival conjectures, counterexample sweeps, and a crucial-experiment queue
argument-hint: [model-id] (default: all live models under kb:/models/)
---

Criticize **$ARGUMENTS**: run the criticism half of the conjecture-and-criticism cycle over the KB's live models. Argument first (most conjectures should die under argument, not experiment): hard-to-vary check, re-derivation from grounding, consistency across models, counterexample sweep. Then the generative attack — conjecture rivals for lone hypotheses — and emit a ranked crucial-experiment queue: the cheapest observations that would refute or discriminate. This pass never confirms anything; survival is the only good news it can deliver.

If $ARGUMENTS is empty, the scope is every live model under `kb:/models/`. If non-empty, it must be a model id (resolve with `$KB_ENGINE_DIR/scripts/kb show <id>`); if it doesn't resolve to a `type: model` entry, output: "Usage: `/criticize [model-id]` (default: whole theory layer)." and stop.

## Procedure

Spawn an Agent subagent (general-purpose). Brief it:

> Read `$KB_ENGINE_DIR/librarian/procedure-criticize.md` and follow it for scope `<resolved scope>`.
>
> Read all of `kb:/models/` in full first (targets AND context — consistency checks need every live statement). Run `$KB_ENGINE_DIR/scripts/kb doctor` to prioritize. Attack each target: hard-to-vary, re-derivation, consistency, counterexample sweep (`kb search`, summary layer). Conjecture a rival for every lone hypothesis — held to the same bars; no strawmen. Build the experiment queue ranked by decisiveness/cost, preferring observations checkable today (Datadog, BigQuery, a repo, one Slack question) and crucial experiments that discriminate rival pairs.
>
> Apply conservatively: sharpen EASY-TO-VARY statements in place (meaning changes supersede instead), append `refuted_by` for KB counterexamples WITHOUT flipping status (flag loudly — Gregor decides), mint surviving rivals as `status: hypothesis` with `rivals` cross-linked on both sides. The experiment queue is report-only. Never add `evidence_for`, never flip anything to `corroborated`, never delete a model. Run `$KB_ENGINE_DIR/scripts/kb sync` then `$KB_ENGINE_DIR/scripts/validate.py` at the end and confirm clean.
>
> Output the procedure's CRITICISM report in full.

After the subagent returns, present its output verbatim. Add:

> Criticism can only refute or fail-to-refute — SOUND means *survived this attack*, nothing more. The experiment queue is the actionable part: run an item, file the episode, and the filing loop settles it. Review with `git -C $KB_DATA_DIR status`; revert with `git -C $KB_DATA_DIR restore .`.

## Constraints

- This pass never corroborates: no `evidence_for` appends, no status upgrades.
- Refutation flags are loud but non-destructive — `status` flips are Gregor's call.
- Rivals must be honest competitors (hard-to-vary, falsifiable) — a strawman rival is padding, not criticism.
- Don't run `git commit`. Gregor reviews and commits manually.

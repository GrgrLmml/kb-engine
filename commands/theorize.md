---
description: Conjecture explanatory models from the KB's open problems and chain them into derived conclusions — the theory layer's growth pass
argument-hint: <kb:/folder> (use kb:/ for whole tree; default whole tree)
---

Theorize over **$ARGUMENTS**: harvest the KB's open *problems* (unexplained episodes, contradictions, untested hypotheses), conjecture `type: model` entries (falsifiable, hard-to-vary claims) that would solve them, pass every candidate through a criticism gate, and chain surviving model statements into derived conclusions. Conjecture and criticism — never induction: models are bold guesses provoked by problems, not patterns extracted from episodes.

If $ARGUMENTS is empty, default the scope to `kb:/` (whole tree). If it's non-empty but doesn't start with `kb:/`, output: "Usage: `/theorize kb:/folder` (or `/theorize` for the whole tree)." and stop.

## Procedure

Spawn an Agent subagent (general-purpose). Brief it:

> Read `$KB_ENGINE_DIR/librarian/procedure-theorize.md` and follow it for scope `<resolved scope>`.
>
> Start from PROBLEMS (`kb doctor` epistemic lines + anomalies/contradictions/open questions in the summary layer), not from patterns. Stay on the summary layer in the survey — do NOT load transcripts to mine; read one only to get a statement right just before writing. Read all of `kb:/models/` first so you refine instead of duplicating, and so existing statements are available as premises for the deduction step.
>
> Conjecture BOLDLY, then run every candidate through the criticism gate (hard-to-vary, falsifiability, consistency, counterexample sweep, relabel check) — nothing is minted without surviving it; rejected candidates appear in the plan with the criticism that killed them. Same episodes + different mechanism = a RIVAL, not a duplicate — mint it and cross-link `rivals` on both sides. Mint survivors as `status: hypothesis` under `kb:/models/` (bootstrap that folder + `_route.md` if absent). One falsifiable, hard-to-vary statement per model; 1–3 risky predictions each; `derived_from` set; `evidence_for` EMPTY (grounding is not corroboration). Chain premises into derivations — every derivation cites all its premise ids and inherits the weakest premise's status. Flag premise contradictions; they are findings (new problems), not failures. Run `$KB_ENGINE_DIR/scripts/kb sync` then `$KB_ENGINE_DIR/scripts/validate.py` at the end and confirm clean.
>
> Bold at generation, severe at the gate. ABORT (write nothing) if judgment is shaky on ≥30% of gate verdicts. Output the procedure's PLAN, then its DONE summary.

After the subagent returns, present its output verbatim. Add:

> These models are **hypotheses** — conjectures that survived criticism, not established facts. Predictions get tested automatically as future episodes are filed; run `/criticize` to attack them and get the crucial-experiment queue. Review with `git -C $KB_DATA_DIR status`; revert with `git -C $KB_DATA_DIR restore .`.

## Constraints

- New models are `status: hypothesis` only. Corroboration comes from later episodes, never from this pass.
- Don't supersede/delete existing models here — supersession is proposed explicitly in the plan.
- Derived conclusions must always carry their premise chain (`[derived: id + id]`) — an unchained conclusion is an opinion, not a deduction.
- Don't run `git commit`. Gregor reviews and commits manually.

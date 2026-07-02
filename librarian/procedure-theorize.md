# Theorize procedure (canonical)

The KB's deduction layer has two moving parts, and this pass builds both:

1. **Abduction** — sweep episodes for a *mechanism* that would explain several of them,
   and mint it as a `type: model` under `kb:/models/`: one falsifiable `statement`
   (the premise) plus `predictions` (its testable consequences). This is how new theory
   enters the KB — analogous to how `/mine-recipes` finds procedures, but for *claims*
   rather than *methods*.
2. **Deduction** — chain existing model statements together and derive conclusions no
   single episode records ("model A + model B ⟹ C"). Derivations that matter get
   recorded as `predictions` on the models involved; the rest are reported.

The Popperian loop closes elsewhere: filing (`procedure-file.md` step 5) checks new
episodes against model predictions, and `kb doctor` flags models whose status and
evidence disagree.

---

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md` (read the Model section)
**Template:** `$KB_ENGINE_DIR/templates/model.md.template`
**Validator:** `$KB_ENGINE_DIR/scripts/validate.py`

You will be told a scope: a `kb:/` folder URI (theorize within that subtree) or `kb:/`
(whole tree).

## Procedure

### 1. Survey (summary layer only — stay cheap)

- Read every leaf entry's frontmatter under the scope (`id`, `title`, `topics`,
  `summary`, `created`, `status`). Do NOT read transcript bodies in this step.
- Read every existing model under `kb:/models/` in full (they're short) — `statement`,
  `predictions`, `derived_from`, `evidence_for`, `refuted_by`, `status`. You need these
  both to avoid re-proposing what exists and as premises for step 3.
- Skip episodes with `status: superseded` or `archived`, and models with
  `status: superseded`.

### 2. Abduce candidate models

Look for a **shared mechanism**, not a shared topic. Signals:

- Several episodes whose root causes are instances of one underlying claim (e.g. three
  "customer reports failures" incidents that were all queue latency vs client timeout —
  the mechanism is the model, the incidents are its instances).
- An episode that *states* a general claim in passing ("X always goes through Y",
  "Z is shared across all customers") that nothing else records as a first-class fact.
- A `contradicts` pair — the resolution of a contradiction is often a boundary
  condition, which is a model ("X holds only when Y").

For each candidate, draft:
- **statement** — ONE falsifiable claim. If it can't be wrong, it's not a model
  (rules out preferences, definitions, and vague tendencies). If it needs "and",
  split it into two models.
- **predictions** — 1–3 consequences a future episode could confirm or refute. A model
  with no checkable prediction is decoration; drop it.
- **derived_from** — the grounding episode ids.

Check against existing models: overlapping statement → **REFINE** the existing model
(sharpen its statement, add a prediction or boundary condition, append `derived_from`)
rather than minting a near-duplicate.

### 3. Deduce — chain the premises

Take all live models (existing + the candidates from step 2), including `hypothesis`
ones, and look for pairs/triples whose statements combine to entail something neither
says alone. For each derivation record:

```
<conclusion>   [derived: <model-id> + <model-id>]
  confidence: <inherits the WEAKEST premise's status — a chain through a hypothesis is a hypothesis>
  checkable by: <what observation would test it>
```

Rules of inference discipline:
- Every derivation cites ALL premises. No premise chain → not a deduction, don't emit it.
- A derivation is only as strong as its weakest premise. Never present a conclusion
  chained through a `hypothesis` as established.
- If two models jointly entail a contradiction with a third, that IS a finding —
  report it; at least one premise is wrong or missing a boundary condition.
- Useful derivations become `predictions` on the participating models (that's how a
  derivation gets tested by the filing loop). Merely-interesting ones stay in the report.

### 4. Output the plan

```
PLAN: theorize under <kb-path>

NEW MODELS (mint as hypothesis):
  - <proposed-slug>  ← derived_from: [<id>, <id>, ...]
      statement: <the claim, one line>
      predictions: <1-3 lines>
      why: <what episodes this mechanism explains>

REFINE (update existing model):
  - <model-id>  + source <entry-id>
      change: <sharpen statement / add prediction / add boundary condition>

DERIVATIONS (chained conclusions):
  - <conclusion>  [derived: <model-id> + <model-id>]  — checkable by: <observation>

CONTRADICTIONS (premises that clash):
  - <model-id> vs <model-id>: <what they jointly entail that can't hold>
```

If no candidate crosses the confidence bar, output `SKIPPED: <reason>` (still print any
derivations/contradictions from existing models) and stop. If judgment is shaky on ≥30%
of the candidates, output `ABORTED: <reason>` and write nothing.

### 5. Apply

- If `kb:/models/` doesn't exist yet: `mkdir` it and create its `_route.md` from the
  route template, filling `type`, `folder: kb:/models`, `title`, and a `purpose` like
  "Declarative models — falsifiable claims about how our systems and processes work,
  the KB's premises for deduction. Minted by /theorize, tested by filing."
- For each **NEW** model: write it from `model.md.template` under `kb:/models/` with
  `status: hypothesis`, `derived_from` set, `evidence_for`/`refuted_by` empty (grounding
  episodes are NOT evidence — that would be circular; only *later* episodes confirm).
  Body: mechanism, why the grounding supports the claim, boundary conditions, reasoning
  behind each prediction.
- For each **REFINE**: edit the model in place, bump `updated:`. If the statement itself
  changed meaning (not just sharpened wording), mint a new model that `supersedes` the
  old instead — statements others may have chained on shouldn't mutate silently.
- Fold accepted derivations into the participating models' `predictions`.
- Then: `$KB_ENGINE_DIR/scripts/kb sync`

### 6. Validate + report

Run `$KB_ENGINE_DIR/scripts/validate.py`. Then:

```
DONE: theorize under <kb-path>
  New hypothesis models: <N>   (<slug>, <slug>, ...)
  Models refined:        <M>
  Derivations recorded:  <K>   (contradictions flagged: <C>)
  Validator: clean
  Next: predictions get checked automatically as new episodes are filed;
        kb doctor flags hypotheses that sit unconfirmed too long.
```

## Constraints

- Summary layer only in the survey — read a transcript only for a candidate you're
  about to write, to get the statement right.
- New models are `status: hypothesis`. Never mint `validated` — only later episodes
  (via the filing loop) validate, never the minting pass and never the grounding episodes.
- One falsifiable claim per model. Reject candidates that are topics, preferences, or
  unfalsifiable tendencies.
- Conservative bias: a wrong premise poisons every chain through it. When unsure,
  don't mint.
- YAML: write `predictions` items as `>-` folded block scalars — inline items
  containing `[derived: ...]`, quotes, or `:` break parsing, and the indexer
  *silently skips* unparseable files (only the validator complains).
- Never delete or supersede a model silently — supersession is explicit in the plan.
- Do NOT run `git commit`. Working-tree changes only; Gregor reviews and commits.

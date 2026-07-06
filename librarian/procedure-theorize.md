# Theorize procedure (canonical)

The KB grows theory the way science does — **conjecture and criticism** (Popper/Deutsch),
never induction. Nothing is "extracted from the data": episodes cannot speak. Knowledge
enters when a *problem* (a conflict between ideas, or between an idea and an episode)
provokes a bold conjecture, and the conjecture survives severe criticism. This pass
runs that cycle over the KB:

1. **Harvest problems** — the queue of open conflicts. All knowledge growth starts here.
2. **Conjecture boldly** — creative guesses at mechanisms that would *solve* a problem.
   Generation is unfiltered; rigor lives at the gate, not the source.
3. **Criticize before minting** — every candidate must pass the criticism gate
   (hard-to-vary, consistency, counterexample sweep). Only survivors become
   `type: model` files under `kb:/models/`.
4. **Deduce** — chain live model statements into conclusions no single episode records.

The empirical loop closes elsewhere: filing (`procedure-file.md` step 5) tests new
episodes against model predictions, `/criticize` attacks the existing theory layer and
proposes crucial experiments, and `kb doctor` keeps the whole loop from silting up.

---

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md` (read the Model section)
**Template:** `$KB_ENGINE_DIR/templates/model.md.template`
**Validator:** `$KB_ENGINE_DIR/scripts/validate.py`

You will be told a scope: a `kb:/` folder URI (theorize within that subtree) or `kb:/`
(whole tree).

## Procedure

### 1. Harvest problems (this is where conjecture starts — not from patterns)

- Run `$KB_ENGINE_DIR/scripts/kb doctor` and collect the epistemic lines: `problem`
  (unresolved contradictions, live rival pairs), `needs-review` (live model with
  refuting evidence), `stale-model` (untested hypotheses).
- Read every leaf entry's frontmatter under the scope (`id`, `title`, `topics`,
  `summary`, `open_questions`, `created`, `status`). Do NOT read transcript bodies.
- Read every existing model under `kb:/models/` in full (they're short) — `statement`,
  `predictions`, `rivals`, `derived_from`, `evidence_for`, `refuted_by`, `status`. You
  need these to know what's already explained and as premises for step 4.
- Skip episodes with `status: superseded` or `archived`, and models with
  `status: superseded`.

From these, write the **problem list**. A problem is a *conflict*, one of:

- **Anomaly** — an episode (or several) whose outcome no live model explains, or that
  is surprising given what the live models jointly entail.
- **Contradiction** — a `contradicts` pair between active entries, or a model vs. an
  episode (`refuted_by` pending review). The resolution of a contradiction is usually a
  boundary condition — which is itself a model ("X holds only when Y").
- **Unexplained success** — a recipe that reliably works for reasons no model states.
- **Open question** — an `open_questions` item that recurs across entries.
- **Prophecy in the wild** — an episode asserting a trend or tendency ("this keeps
  happening more") with no stated mechanism. The trend is not knowledge; the missing
  explanation is the problem.

No problems in scope → output `SKIPPED: no open problems` (still run step 4 on existing
models — deduction needs no new conjectures) and stop after reporting.

### 2. Conjecture boldly

For each problem, guess **mechanisms that would solve it** — explanations, not
regularities. "L4s are usually scarce" is a pattern summary and worthless as theory;
"GCP's on-demand L4 pool in us-central1 is structurally undersized relative to standing
reservations, so on-demand requests fail whenever N > threshold" is a mechanism —
it has consequences beyond the episodes that provoked it (reach).

- Be bold. Do NOT self-censor at this step; timid conjectures produce a timid KB.
  A wrong conjecture that dies at the gate costs nothing; the gate is next.
- Where a live model already covers the territory but a problem persists, conjecture a
  **rival**: a different mechanism explaining the same episodes. Rivals are valuable —
  a lone hypothesis can only be believed; a rival pair can be *discriminated*.
- For each candidate draft:
  - **statement** — ONE falsifiable claim. If it can't be wrong, it's not a model
    (rules out preferences, definitions, and vague tendencies). If it needs "and",
    split it into two models.
  - **predictions** — 1–3 consequences a future episode could corroborate or refute.
    Prefer *risky* predictions — ones a rival (or common sense) would bet against.
  - **derived_from** — the grounding episode ids.
  - **solves** — which problem(s) from step 1 this conjecture answers (for the plan).

Check against existing models: overlapping statement → **REFINE** the existing model
(sharpen its statement, add a prediction or boundary condition, append `derived_from`)
rather than minting a near-duplicate. Same episodes, *different* mechanism → that's a
**RIVAL**, not a duplicate — keep it and cross-link `rivals` both ways.

### 3. Criticize — the gate. Nothing is minted without passing it.

Attack every candidate (argument is cheap; most criticism needs no experiment):

- **Hard-to-vary check**: could the statement be altered — mechanism swapped, direction
  flipped, constant changed — and still "explain" the same grounding episodes? If yes,
  it's a bad explanation regardless of how well it fits. Sharpen until every part of
  the statement is load-bearing, or kill it.
- **Falsifiability check**: is there a describable observation that would refute it?
  No → kill (it's a preference or a definition wearing a lab coat).
- **Consistency check**: does it clash with any live model? A clash is not
  disqualifying — it may be a rival (cross-link) or it may expose a problem in the
  *existing* model (report it in the plan). But it must be surfaced, never shipped
  silently.
- **Counterexample sweep**: `kb search` the candidate's key terms; scan episode
  summaries in and out of scope for an episode that already refutes it. Found one →
  kill or add the boundary condition now (the episode goes in the body's boundary
  discussion, NOT in `refuted_by` — a model minted pre-refuted shouldn't exist).
- **Problem check**: does it actually solve the problem it was conjectured for, or
  merely relabel it? ("Why does X fail?" — "Because X has a failure-proneness" is a
  relabel.) Relabels die.

Candidates that die at the gate are listed in the plan as REJECTED with the killing
criticism — a dead conjecture is a finding too.

### 4. Deduce — chain the premises

Take all live models (existing + gate survivors), including `hypothesis` ones, and look
for pairs/triples whose statements combine to entail something neither says alone. For
each derivation record:

```
<conclusion>   [derived: <model-id> + <model-id>]
  confidence: <inherits the WEAKEST premise's status — a chain through a hypothesis is a hypothesis>
  checkable by: <what observation would test it>
```

Rules of inference discipline:
- Every derivation cites ALL premises. No premise chain → not a deduction, don't emit it.
- A derivation is only as strong as its weakest premise. Never present a conclusion
  chained through a `hypothesis` as established — corroborated premises make
  corroborated-at-best conclusions.
- If two models jointly entail a contradiction with a third, that IS a finding —
  report it as a new problem; at least one premise is wrong or missing a boundary
  condition.
- Useful derivations become `predictions` on the participating models (that's how a
  derivation gets tested by the filing loop). Merely-interesting ones stay in the report.

### 5. Output the plan

```
PLAN: theorize under <kb-path>

PROBLEMS (harvested in step 1):
  - P1: <one-line conflict>  [<episode/model ids involved>]

NEW MODELS (survived criticism; mint as hypothesis):
  - <proposed-slug>  ← solves: P<n>; derived_from: [<id>, <id>, ...]
      statement: <the claim, one line>
      predictions: <1-3 lines>
      criticism survived: <the strongest attack from step 3 and why it failed>

RIVALS (competing explanations for the same episodes — cross-link both ways):
  - <slug-a> vs <slug-b>: <what observation would discriminate them>

REFINE (update existing model):
  - <model-id>  + source <entry-id>
      change: <sharpen statement / add prediction / add boundary condition>

REJECTED (died at the gate — recorded, not filed):
  - <candidate>: <the criticism that killed it>

DERIVATIONS (chained conclusions):
  - <conclusion>  [derived: <model-id> + <model-id>]  — checkable by: <observation>

CONTRADICTIONS (premises that clash — new problems for the queue):
  - <model-id> vs <model-id>: <what they jointly entail that can't hold>
```

If judgment is shaky on ≥30% of the gate verdicts, output `ABORTED: <reason>` and
write nothing.

### 6. Apply

- If `kb:/models/` doesn't exist yet: `mkdir` it and create its `_route.md` from the
  route template, filling `type`, `folder: kb:/models`, `title`, and a `purpose` like
  "Declarative models — falsifiable claims about how our systems and processes work,
  the KB's premises for deduction. Conjectured by /theorize, criticized by /criticize,
  tested by filing."
- For each **NEW** model: write it from `model.md.template` under `kb:/models/` with
  `status: hypothesis`, `derived_from` set, `evidence_for`/`refuted_by` empty (grounding
  episodes are NOT corroboration — that would be circular; only *later* episodes test).
  Body: the mechanism, which problem it solves, why the grounding supports the claim,
  the criticism it survived, boundary conditions, and the reasoning behind each
  prediction.
- For each **RIVAL** pair: set `rivals:` on BOTH models (symmetric), bump `updated:` on
  the existing side.
- For each **REFINE**: edit the model in place, bump `updated:`. If the statement itself
  changed meaning (not just sharpened wording), mint a new model that `supersedes` the
  old instead — statements others may have chained on shouldn't mutate silently.
- Fold accepted derivations into the participating models' `predictions`.
- Then: `$KB_ENGINE_DIR/scripts/kb sync`

### 7. Validate + report

Run `$KB_ENGINE_DIR/scripts/validate.py`. Then:

```
DONE: theorize under <kb-path>
  Problems harvested:    <P>   (open after this pass: <Q>)
  New hypothesis models: <N>   (<slug>, <slug>, ...)
  Rival pairs linked:    <R>
  Models refined:        <M>
  Rejected at the gate:  <X>
  Derivations recorded:  <K>   (contradictions flagged: <C>)
  Validator: clean
  Next: predictions get tested automatically as new episodes are filed;
        /criticize attacks the live models and proposes crucial experiments;
        kb doctor keeps the problem queue visible.
```

## Constraints

- Summary layer only in the survey — read a transcript only for a candidate you're
  about to write, to get the statement right.
- New models are `status: hypothesis`. Never mint `corroborated` — only later episodes
  (via the filing loop) corroborate, never the minting pass and never the grounding
  episodes.
- One falsifiable, hard-to-vary claim per model. Regularities, trends, preferences, and
  unfalsifiable tendencies are not models — a trend without a mechanism is prophecy.
- **Bold at generation, severe at the gate.** Don't self-censor conjectures; don't let
  anything through criticism un-attacked. A wrong premise poisons every chain through
  it — but the defense is the gate + the weakest-premise rule + `/criticize`, not
  timidity.
- YAML: write `predictions` items as `>-` folded block scalars — inline items
  containing `[derived: ...]`, quotes, or `:` break parsing, and the indexer
  *silently skips* unparseable files (only the validator complains).
- Never delete or supersede a model silently — supersession is explicit in the plan.
- Do NOT run `git commit`. Working-tree changes only; Gregor reviews and commits.

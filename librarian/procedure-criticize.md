# Criticize procedure (canonical)

`/theorize` grows the theory layer; this pass **attacks** it. In the
conjecture-and-criticism cycle (Popper/Deutsch) this is the criticism half run as a
standing audit: most conjectures should die under *argument* — inconsistency,
easy variability, an overlooked counterexample — long before any experiment runs.
What survives argument gets an **experiment queue**: for each live model (and
especially each rival pair), the cheapest observation that would refute or
discriminate. Criticism never *confirms* anything — a model that survives this pass
has merely survived.

This pass proposes experiments; it does not run them. Gregor (or a later session)
runs one, files the episode, and the filing loop (`procedure-file.md` step 5) settles
the score.

---

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md` (read the Model section)
**Validator:** `$KB_ENGINE_DIR/scripts/validate.py`

You will be told a scope: a single model id, or nothing (criticize the whole live
theory layer under `kb:/models/`).

## Procedure

### 1. Load the theory layer

- Read every model under `kb:/models/` in full (they're short). In-scope models are
  the targets; the rest are context (consistency checks need all of them).
- Skip `status: superseded` and `refuted` models as targets (they're already dead),
  but keep their statements in mind — a new model quietly re-asserting a refuted one
  is a finding.
- Run `$KB_ENGINE_DIR/scripts/kb doctor` and note the model-related lines (`problem`,
  `needs-review`, `stale-model`) — they prioritize the attack order.

### 2. Attack each target model (argument first — cheap and decisive)

Run all four attacks; record a verdict per model.

- **Hard-to-vary**: could the statement be altered — mechanism swapped, direction
  flipped, threshold moved — and still "explain" its `derived_from` episodes equally
  well? If yes, the model is a bad explanation *regardless of its evidence*. Propose
  the sharpened statement that closes the slack, or the verdict is EASY-TO-VARY.
- **Re-derivation**: read the `derived_from` episode summaries (transcripts only if a
  summary is ambiguous). Do they still support the statement, or was the conjecture
  reading tea leaves? Grounding that evaporates under a second look is a finding.
- **Consistency**: does the statement clash with any other live model, or jointly
  with another entail something a third denies? Surface every clash — each is either
  a rival relationship to record or a boundary condition someone is missing.
- **Counterexample sweep**: `kb search` the model's key terms (2–3 query variants,
  `--all-status`); scan episode summaries for one filed episode that contradicts the
  statement or a prediction. Found → verdict REFUTED-BY-KB (append the id to
  `refuted_by` in the apply step; Gregor decides death vs. boundary condition).

Then the generative attack:

- **Rival conjecture**: for each target — mandatory for models sitting `hypothesis`
  with no `rivals` — try to conjecture a *different mechanism* explaining the same
  `derived_from` episodes. A lone hypothesis can only be believed; a rival makes it
  testable by discrimination. Hold rival candidates to the same hard-to-vary and
  falsifiability bars (a strawman rival is noise, not criticism). No honest rival
  survives your own gate → say so; that itself raises confidence in the incumbent.

### 3. Build the experiment queue

For every surviving model and every rival pair, propose the **cheapest decisive
observation**:

- For a **rival pair**: the crucial experiment — one observation the two statements
  predict *differently*. This is the highest-value item; it kills a model whichever
  way it lands.
- For a **lone model**: the riskiest untested prediction — the one most likely to
  fail if the model is wrong (never the one most likely to hold; confirmation-seeking
  is worthless). Prefer predictions checkable *today* against Datadog / BigQuery / a
  repo / one Slack question over waiting for an incident to happen along.

Rank the queue by `decisiveness / cost`. Each item names: the model id(s), the exact
observation, where to look (dashboard, query, repo, person), and what each outcome
would mean.

### 4. Output the report

```
CRITICISM: <scope>

VERDICTS:
  - <model-id>: SOUND — survived all four attacks (strongest attack: <which, and why it failed>)
  - <model-id>: EASY-TO-VARY — <the slack>; proposed sharper statement: <one line>
  - <model-id>: REFUTED-BY-KB — <episode-id> contradicts <statement/prediction>
  - <model-id>: INCONSISTENT — clashes with <model-id>: <what can't jointly hold>

NEW RIVALS (mint as hypothesis, cross-link both ways):
  - <proposed-slug> rivals <model-id>
      statement: <the competing mechanism, one line>
      discriminated by: <the observation that would pick a winner>

EXPERIMENT QUEUE (ranked, cheapest-decisive first):
  1. [<model-id> vs <model-id>] <observation> — where: <source>. If <outcome-A> → <verdict>; if <outcome-B> → <verdict>.
  2. [<model-id>] <riskiest prediction test> — where: <source>. Fails → refuted; holds → corroborated.
```

If every target is SOUND and no rival survives your gate, say exactly that — a clean
bill from a serious attack is information; a clean bill from a soft one is decoration.

### 5. Apply

- **EASY-TO-VARY** with an accepted sharper statement → REFINE in place (bump
  `updated:`); if the meaning changed (not just tightened), mint a successor that
  `supersedes` instead — chained statements must not mutate silently.
- **REFUTED-BY-KB** → append the episode id to `refuted_by`, bump `updated:`, leave
  `status` untouched and flag loudly — Gregor decides refuted vs. boundary condition.
- **NEW RIVALS** → write from `model.md.template`, `status: hypothesis`,
  `derived_from` = the same episodes they reinterpret, `evidence_for`/`refuted_by`
  empty, `rivals` set on BOTH sides (bump `updated:` on the incumbent). Body: the
  mechanism, why the same episodes admit this reading, and the discriminating
  observation.
- **INCONSISTENT** pairs where neither statement is wrong on its face → record the
  clash in both bodies' boundary-condition discussion and flag as an open problem.
- The experiment queue is REPORT-ONLY — do not run experiments, do not write queue
  files. It lives in the report; acting on it is Gregor's call.
- Then: `$KB_ENGINE_DIR/scripts/kb sync` and `$KB_ENGINE_DIR/scripts/validate.py`.

## Constraints

- Criticism only — this pass never flips a model to `corroborated`, never adds
  `evidence_for`, and never deletes a model. Its outputs are attacks, rivals,
  refutation flags, and the experiment queue.
- Attacks must be honest: a rival you wouldn't bet a lunch on, or a "criticism" the
  statement trivially answers, is padding — drop it.
- Read transcripts only when a summary is genuinely ambiguous about whether it
  contradicts a statement.
- Never flip `status` to `refuted` yourself — flag and let Gregor decide.
- Do NOT run `git commit`. Working-tree changes only; Gregor reviews and commits.

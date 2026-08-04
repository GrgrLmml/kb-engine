# Run-experiment procedure (canonical)

`/criticize` designs crucial experiments and stores them, pre-registered, in the
problem ledger (`kb:/problems/`, `status: ready`). This procedure executes ONE of
them and resolves the problem. It is the only place in the whole system where a
model's `status` flips semi-automatically — and it still requires Gregor's explicit
confirmation, because a model dying is a decision, not a side effect.

Interactive-only: the observation surfaces (Datadog, BigQuery, Slack, repos, people)
live in the session's tools. Never run this headless.

---

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md` (Problem and Model sections)
**Ledger CLI:** `$KB_ENGINE_DIR/scripts/kb problems …`

## Procedure

### 1. Load

- Given a problem id → `kb show <id>`; it must be `status: ready` (an `open` problem
  has no experiment yet — that's /criticize's job, say so and stop).
- Given nothing → `kb problems list --status ready`; propose the best
  `decisiveness / cost` item and confirm the choice with Gregor before proceeding.
- Read the problem file in full, and every model in its `models:` list in full.

### 2. Pre-register (the contract)

Restate to Gregor, verbatim from the problem file, BEFORE touching any tool:

- the `observation` to make,
- `where` to look,
- the `outcomes` table — what each result means for which model.

This is the contract. After data is seen, results may only be mapped onto these
pre-registered outcomes — never reinterpreted, never extended with a convenient
third reading. If mid-experiment you realize the design itself is wrong, stop and
treat that as an ambiguous result (step 4), not as license to improvise.

### 3. Observe

- Make the observation — and only that observation — using the session's real tools
  (Datadog/BigQuery MCP, `bq`, repo reads, one Slack question, …).
- Record verbatim what you ran and what came back (queries, numbers, timestamps).
  This becomes the evidence body of the filed episode.
- Surface unreachable (MCP not connected, person unavailable, data retention
  expired)? Write a `blocked: <reason, date>` note into the problem body, leave
  `status: ready`, report, and stop.

### 4. Verdict

Map the observation onto the pre-registered outcomes:

- **Clean match to one outcome** → that outcome's verdict stands. State it.
- **Ambiguous** (matches no outcome, or the data is equivocal) → that is itself a
  finding: the experiment was under-designed. Refine the `experiment:` block
  (sharper observation or added outcome), bump `updated:`, keep `status: ready`,
  and report honestly. Do NOT pick a winner from ambiguous data.

### 5. Confirm and apply

Ask Gregor one question: accept the verdict? On yes:

1. **File the run as a normal episode** (follow `procedure-file.md`, lightweight):
   the observation made, exact queries/numbers, the verdict, `related:` → the
   problem and the models. This is the durable evidence record.
2. **Update the models:**
   - Winner: append the episode id to `evidence_for`, bump `updated:`; if this is
     its first surviving later test, flip `status: hypothesis → corroborated`
     (survived, never proven).
   - Loser: append the episode id to `refuted_by`, and either flip
     `status: → refuted`, or — if the outcome revealed a boundary condition rather
     than a corpse — mint a narrowed successor that `supersedes` it
     (procedure-theorize's supersession rule; statements others may have chained on
     must not mutate silently).
   - Remove the pair from both models' `rivals` lists — the crucial experiment has
     landed (schema.md's rivals contract).
3. **Resolve the ledger:**
   `kb problems resolve <problem-id> --by <episode-id> --note "<one line: who died / what narrowed>"`
4. `$KB_ENGINE_DIR/scripts/kb sync` and `$KB_ENGINE_DIR/scripts/validate.py`.

On no: leave everything untouched except a body note recording the observation and
Gregor's objection; keep `status: ready`.

### 6. Report

```
RESOLVED <problem-id>: <model> refuted by <episode-id>; <model> corroborated.
Ledger: <n> ready remain, <n> open await /criticize.
```

(or `AMBIGUOUS <problem-id>: <what the data couldn't discriminate>; experiment refined.`)

## Constraints

- One experiment per invocation — resolution quality beats throughput.
- The pre-registered outcomes are binding. Post-hoc reinterpretation is the exact
  failure mode this ledger exists to prevent.
- Never resolve without a filed episode (`kb problems resolve` enforces `--by`).
- Status flips happen only here and only after Gregor's explicit yes.
- Do NOT run `git commit`. Working-tree changes only; Gregor reviews and commits.

# KB schema

Five file shapes live in `kb-data/`:

1. **Leaf entries** — one per filed conversation (episodic). Filename: `<YYYY-MM-DD>-<slug>.md`.
2. **Recipes** — reusable procedures distilled from one or more conversations (evergreen, `type: recipe`). Filename: `<slug>.md` (no date prefix). Live under `kb:/recipes/`.
3. **Models** — declarative claims about how something works (evergreen, `type: model`). Filename: `<slug>.md` (no date prefix). Live under `kb:/models/`.
4. **Problems** — the epistemic ledger: durable open conflicts, each carrying its pre-registered crucial experiment (`type: problem`). Filename: `<slug>.md`. Live under `kb:/problems/`.
5. **`_route.md`** — one per folder. The folder index. Used by the retriever to traverse without loading leaves.

All paths inside frontmatter use the **`kb:/` URI scheme**, rooted at the kb-data directory (e.g. `kb:/people/alex/_route.md`). Tooling resolves `kb:/` → `$KB_DATA_DIR/` at read time. The scheme makes it impossible to confuse with a filesystem path.

External references (issue tracker, chat, code permalinks, knowledge tools) keep their normal `https://` URLs unchanged; `gs://` artifact URIs are also allowed in `sources`. Local file paths and prose descriptions are NOT sources — put them in the body. `id` references in `supersedes` / `contradicts` / `superseded_by` are bare ids, not paths.

All timestamps are **ISO 8601 UTC** (e.g. `2026-05-05T14:30:00Z`).

---

## Leaf entry frontmatter

```yaml
---
id: 2026-05-05-1to1-alex-prep         # stable. Date prefix + slug. Never changes after creation.
title: 1:1 prep with Alex — Q2 priorities
created: 2026-05-05T14:30:00Z         # when the conversation happened
updated: 2026-05-05T14:30:00Z         # bumped by the librarian on any edit (dedup, contradiction flag, etc.)
participants: [me, alex]              # entities. Free-form for now; normalization is a later layer.
topics: [1to1, alex, q2-planning]     # tags. Normalized against kb-data/_topics.yaml (controlled vocabulary + polysemy guard).
related:                              # cross-graph links. Cyclic ok. kb:/ scheme.
  - kb:/people/alex/_route.md
  - kb:/processes/1to1/_route.md
sources:                              # external pointers (issue tracker / chat / code permalinks / gs:// artifacts). http(s) or gs:// only. Optional.
  - https://example.atlassian.net/browse/...
status: active                        # active | superseded | archived
supersedes: []                        # ids of entries this replaces (newest-wins)
superseded_by: null                   # set when something later replaces this
contradicts: []                       # ids of entries this disagrees with — librarian flags these in summary
recipe_candidate: false               # true if this conversation looks like a reusable procedure (auto-flag for the recipe mining pass)
decisions:
  - Bump priority of X over Y
open_questions:
  - When does the migration land?
claims: []                            # keyed facts this episode asserts (see "Claims" below)
summary: |
  Two-paragraph distilled summary. This is the WARM-tier payload — the routing
  agent reads only this to decide whether to load the full transcript.
---

(raw transcript follows the frontmatter)
```

### Required fields

`id`, `title`, `created`, `updated`, `status`, `summary`. Everything else may be empty (`[]` or `null`) but must be present so the schema is uniform.

### Field semantics

- **`id`**: Stable forever. References from other files resolve through this id, not through the file path. The librarian's link-fix pass uses ids when files move.
- **`status`**: `active` is the default. `superseded` means a newer entry replaces this one (set `superseded_by` to its id). `archived` means kept for history but excluded from default retrieval.
- **`supersedes` / `superseded_by`**: Forward + back pointers for the newest-wins rule. The librarian sets both sides when it dedups.
- **`contradicts`**: Ids of entries this disagrees with. The librarian adds a one-line note to `summary` when it sets this.
- **`recipe_candidate`**: Optional boolean (default absent/`false`). Set `true` at filing time when the conversation looks like a *reusable procedure* — it composed several tools/data sources and reached a repeatable outcome. The recipe mining pass (`/mine-recipes`) uses this as a cheap priority signal: `grep -rl 'recipe_candidate: true'`. It's a hint, not a commitment — mining still judges before minting a recipe.
- **`summary`**: Load-bearing. The retriever decides HOT/WARM/COLD based on this. Keep it self-contained — a reader who only sees the summary should still understand what the entry is about.
- **`claims`**: Optional list of keyed facts this episode asserts — see the next section.

### Claims (`claims:` on a leaf entry)

A **claim** is a decision with a key: *subject X currently has value V (in scope S), since D*.
Where `decisions` are prose, claims are addressable — the engine can tell that two episodes
speak about the same thing, which one is newer, and whether they agree. Claims live in the
episode that asserted them (provenance for free; episodes stay immutable). Everything else —
which claim is current, what superseded what, what was re-confirmed, what has gone stale —
is **derived** by `kb` from the `(subject, scope)` key and dates. Nothing derived is ever
written back into the file.

```yaml
claims:
  - subject: search.retrieval.similarity    # dotted key: <area>.<thing>.<attribute>  (see _subjects.yaml)
    value: lexical scoring (token overlap) for the ranked candidate list
    since: 2026-05-22                       # YYYY-MM-DD the value became true (default: the episode date)
    kind: observed                          # observed | inferred | reported  (default: observed)
    source: https://example.atlassian.net/browse/TICKET-123
  - subject: search.retrieval.similarity
    value: dense vector cosine — the tokenizer cannot segment these scripts
    scope: {src_lang: [xx, yy]}             # dimension -> value or list; omitted = the default
    since: 2026-05-22
```

Rules (deterministic, in `kb`):

- **Key** = `(subject, scope)`. Same key, later `since`, different `value` → the older claim is
  superseded (`kb facts --history` shows the chain). Same value → the older claim is *confirmed*
  (its `confirmed` date moves forward), which resets the staleness clock.
- **Scope resolution**: `kb facts <subject> --scope k=v` picks the most specific applicable
  claim; the unscoped claim is the default. Exceptions are therefore first-class, not prose.
- **As-of**: `kb facts <subject> --as-of 2026-05-01` answers "what was true then".
- **Staleness**: each subject has a decay class (`_subjects.yaml`: `config` 90 d, `topology`
  180 d, `relational` 180 d, `never`). An unconfirmed current claim older than its half-life is a
  `kb doctor: stale-claim` finding — re-verify it (a new episode with the same value) or
  supersede it.
- **Conflict**: same key, same `since`, different values → `kb doctor: conflict`.
- **`kind`** travels with every served claim: `observed` (seen in code/data/logs), `inferred`
  (concluded), `reported` (someone said so). An `observed` claim overridden by a weaker kind is
  flagged (`weak-supersession`).
- **Subjects** are a living vocabulary: `kb sync` auto-registers any new subject in
  `_subjects.yaml`; `aliases` and `decay` are hand-curated there. Before minting a subject, check
  `kb subjects --match <words>` for an existing key.

What makes a good claim: it is about the *current state* of a system, process, ownership or
setting ("the LLM translation path samples at temperature 0", "monitor 1234 filters on
test_set gold-v2"), not a to-do and not a narrative. If it could be false tomorrow because
the world changed, it is a claim. If it is history ("we decided X on date D"), it is a decision.

---

## Recipe frontmatter (`type: recipe`)

A recipe is a **reusable procedure** — "how we do X" — distilled from one or more episodic
entries. Where a leaf entry is dated, single-conversation, and decays by being *superseded*,
a recipe is evergreen, multi-source, and decays by going *stale* (the script/dashboard/table
it points at moves). Recipes live under `kb:/recipes/` and ride the same `_route.md` graph,
so `/find` and `/start` surface them for free.

```yaml
---
type: recipe
id: monday-catchup-briefing           # slug only, NO date prefix. Stable. Matches filename stem.
title: Monday catch-up briefing
created: 2026-06-09T00:00:00Z         # when the recipe was first distilled
updated: 2026-06-09T00:00:00Z         # bumped on any edit
status: active                        # active | draft | superseded
when_to_use: |                        # the trigger — when you'd reach for this. Load-bearing for /start.
  Returning from time off or starting a week; you need a ranked "what needs my intervention" view.
inputs: [window_start, today]         # parameters the recipe is templated on (free-form names)
tools: [jira, slack, datadog, kb-find, writing-style]  # NORMALIZED against _tools.yaml (like topics)
topics: [catch-up, briefing]          # normalized against _topics.yaml, as usual
steps:                                # concise ordered outline (WARM). Full detail lives in the body.
  - Fix window_start (last working day) and today; they drive every query.
  - Run four sweeps in parallel — Jira (JQL), Slack (to:me), Datadog (incidents+monitors), KB /find.
  - Synthesize a ranked "where your intervention is required" briefing.
skill: null                           # null, or the name of the Claude Code skill this graduated into
derived_from:                         # provenance — bare ids of the episodic entries this abstracts
  - 2026-06-01-monday-briefing-playbook
related:                              # kb:/ cross-links, as usual
  - kb:/work/catch-up-briefings/_route.md
sources: []                           # external pointers (Jira/Slack/code), optional
supersedes: []                        # bare ids of recipes this replaces (newest-wins)
superseded_by: null
last_verified: 2026-06-01T00:00:00Z   # null, or when the procedure was last actually run end-to-end OK
summary: |
  Two-paragraph WARM-tier summary — what the procedure achieves and the shape of it.
---

# <title>

The full step-by-step procedure: exact commands, queries, gotchas, output structure, and
pointers to the skills/commands it composes. This body is the HOT payload — loaded when you
actually run the recipe. The `steps` outline above is the WARM scan.
```

### Required fields

`type` (always `recipe`), `id`, `title`, `created`, `updated`, `status`, `when_to_use`,
`tools`, `steps`, `summary`. The rest (`inputs`, `topics`, `skill`, `derived_from`, `related`,
`sources`, `supersedes`, `superseded_by`, `last_verified`) may be empty/`null` but the keys
must be present.

### Field semantics

- **`id`**: Slug only, **no date prefix** (recipes are evergreen). Stable forever; matches the filename stem.
- **`status`**: `active` is the default. `draft` means proposed/unverified (e.g. minted by the mining pass, awaiting your review). `superseded` means a newer recipe replaces this one (set `superseded_by`).
- **`when_to_use`**: The trigger. `/start` reads this to decide whether a recipe is relevant to an intent. Make it match how you'd describe the *situation*, not the steps.
- **`tools`**: Normalized list of the skills / commands / data sources the recipe touches (`jira`, `slack`, `datadog`, `mysql`, `vector-db`, `kb-find`, …). Normalized against `_tools.yaml` the same way topics are normalized against `_topics.yaml`. Makes "every recipe that touches Datadog" a real query.
- **`steps`**: Concise ordered outline — one line each. The runnable detail lives in the body.
- **`skill`**: When a recipe is stable and deterministic enough it can graduate into a real Claude Code skill; set this to the skill's name and the recipe becomes the human-readable doc behind it. `null` until then.
- **`derived_from`**: Bare ids of the episodic entries this recipe was distilled from. Provenance — the recipe analogue of `supersedes`. When a later session does the procedure better, append its entry id and refine the recipe in place.
- **`last_verified`**: When the procedure was last actually executed end-to-end successfully. The recipe analogue of `last_indexed` — drives a staleness pass (a runbook pointing at a script that has since moved is the failure mode).
- **`summary`**: Load-bearing, same as for leaf entries.

---

## Model frontmatter (`type: model`)

A model is a **declarative claim** — "how it works / what is true" — where an entry is
"what happened" and a recipe is "how we do X". Models are the KB's theory layer: the
explicit premises that deduction chains together to derive conclusions no single entry
records. The epistemology is conjecture-and-criticism (Popper/Deutsch): models are
**conjectured** by `/theorize` in response to *problems* (unexplained episodes,
contradictions), **criticized** by `/criticize` (hard-to-vary check, rival conjectures,
counterexample sweeps, crucial experiments), consulted at answer time (`kb-researcher`,
`kb-recall`), and corroborated or refuted as new episodes get filed. A model is never
proven — `corroborated` means it has survived testing so far. The quality bar is a
**good explanation**: falsifiable AND hard to vary (every part of the statement
load-bearing). Models live under `kb:/models/` and ride the same `_route.md` graph.

```yaml
---
type: model
id: api-shared-queue-contention       # slug only, NO date prefix. Stable. Matches filename stem.
title: Shared API queue — client timeouts under backlog
created: 2026-07-02T00:00:00Z         # when the model was first stated
updated: 2026-07-02T00:00:00Z         # bumped on any edit or status change
status: hypothesis                    # hypothesis | corroborated | refuted | superseded
statement: |                          # LOAD-BEARING — the premise itself, one falsifiable, hard-to-vary claim.
  The API tier serves all tenants from one shared request queue. Any client
  whose timeout is shorter than queue latency under backlog will report
  failures, regardless of that client's own traffic volume.
predictions:                          # testable consequences deduced from the statement
  - A tenant's "failure" rate tracks global queue load, not their own volume.
  - Raising a client timeout above worst-case queue latency eliminates its failures without any server change.
derived_from:                         # abduction provenance — episode ids that suggested the model
  - 2026-06-29-acme-timeouts-shared-queue
evidence_for:                         # episode ids where a prediction later held
  - 2026-06-26-synthetic-load-test-queue-backlog
refuted_by: []                        # episode ids that contradict the model (any non-empty -> review status)
rivals: []                            # ids of competing models explaining the same episodes (symmetric — set both sides)
topics: [api, queue-contention]       # normalized against _topics.yaml, as usual
related:                              # kb:/ cross-links, as usual
  - kb:/work/infrastructure/_route.md
sources: []                           # external pointers, optional
supersedes: []                        # bare ids of models this replaces (newest-wins)
superseded_by: null
summary: |
  Two-paragraph WARM-tier summary — what the model claims, what grounds it, and
  what it lets you derive.
---

# <title>

The full argument: the mechanism, why the grounding episodes support the claim, known
boundary conditions (where the model does NOT apply), and the reasoning behind each
prediction. This body is the HOT payload.
```

### Required fields

`type` (always `model`), `id`, `title`, `created`, `updated`, `status`, `statement`,
`summary`. The rest (`predictions`, `derived_from`, `evidence_for`, `refuted_by`,
`rivals`, `topics`, `related`, `sources`, `supersedes`, `superseded_by`) may be
empty/`null` but the keys must be present.

### Field semantics

- **`id`**: Slug only, **no date prefix** (models are evergreen and revisable in place). Stable forever; matches the filename stem.
- **`status`**: `hypothesis` — conjectured (e.g. by `/theorize`), not yet tested by a later episode. `corroborated` — at least one prediction held in a *later* episode (`evidence_for` non-empty). Deliberately not "validated": corroboration means *survived testing so far*, never proven — one counterexample still kills it. `refuted` — a counterexample landed (`refuted_by` non-empty); keep the file, it documents a dead end. `superseded` — replaced by a sharper model (set `superseded_by`).
- **`statement`**: The premise deduction actually uses. One claim, stated so it *could* be false, and **hard to vary**: if the statement could be tweaked and still "explain" the same grounding episodes, it's a bad explanation — sharpen it until every part is load-bearing. If you need two claims, write two models — small premises compose; blobs don't.
- **`predictions`**: Consequences that follow deductively from the statement, phrased so a future episode can corroborate or refute them. This is what the filing pass checks new entries against. The best predictions are *risky* — ones a rival model (or common sense) would bet against.
- **`derived_from` vs `evidence_for`**: `derived_from` is where the model *came from* (those episodes can't also count as corroboration — that would be circular). `evidence_for` is episodes filed *after* the model that match a prediction. Only `evidence_for` justifies `corroborated`.
- **`refuted_by`**: The Popperian edge. One solid counterexample outweighs any amount of corroboration; when set, flip status to `refuted` (or refine the statement's boundary conditions and keep it `hypothesis`).
- **`rivals`**: Ids of live models that explain the same episodes differently — competing conjectures awaiting a crucial experiment. Symmetric: set the field on both models. A lone hypothesis can't be discriminated, only believed; rivals are what make criticism decisive. `kb doctor` surfaces live rival pairs as open problems; `/criticize` mints rivals and proposes the discriminating observation. When the crucial experiment lands, one side goes `refuted` (or gains a boundary condition) — remove the pair from both `rivals` lists then.
- **`summary`**: Load-bearing, same as for leaf entries.

---

## Problem frontmatter (`type: problem`)

Problems are the **epistemic ledger** — durable open conflicts in the theory layer,
living under `kb:/problems/` with a lifecycle. `kb problems scan` mints stubs
deterministically from `kb doctor` findings; `/criticize` designs the pre-registered
crucial experiment and flips `open → ready`; `/run-experiment` makes the observation
and flips `ready → resolved`. Resolution is the KB's growth metric.

```yaml
---
type: problem
id: rivals-model-a-vs-model-b         # evergreen slug; matches filename stem
title: model-a vs model-b — undiscriminated rivals
created: 2026-08-04T10:00:00Z
updated: 2026-08-04T10:00:00Z
status: open                          # open → ready → resolved | dropped
kind: rivals                          # rivals | refuted-review | contradiction | anomaly | open-question
fingerprint: "rivals:model-a|model-b" # deterministic key; scan reconciles on this
models: [model-a, model-b]            # bare ids of the leaves this problem is about (indexed as edges)
experiment:                           # null while open; required once ready
  observation: >-
    The ONE observation to make — written before anyone looks at data.
  where: >-
    Exact surface: Datadog query / BigQuery table / repo path / person.
  outcomes:                           # pre-registered meaning of each result — the anti-post-hoc contract
    - if: result A
      then: model-a REFUTED; model-b corroborated
    - if: result B
      then: model-b refuted or narrowed to a boundary condition
  cost: one Datadog session (~10 min)
  decisiveness: high                  # high | medium | low — high kills a model whichever way it lands
resolved_by: null                     # episode id of the filed experiment run (required once resolved)
resolution: null                      # one line: who died / what narrowed
topics: [gpu, capacity-planning]
related: [kb:/models/model-a.md, kb:/models/model-b.md]
sources: []
summary: >-
  What is unresolved and why it matters — WARM-tier self-contained.
---

Why this is a problem: what each side claims, which episodes ground each reading,
what a resolution would change.
```

### Required fields

`type` (always `problem`), `id`, `title`, `created`, `updated`, `status`, `kind`,
`fingerprint`, `summary`. `models`, `experiment`, `resolved_by`, `resolution`,
`topics`, `related`, `sources` may be empty/`null` but should be present.

### Field semantics

- **`fingerprint`**: The deterministic reconciliation key (`<kind>:<sorted ids>`). `kb problems scan` uses it to keep the ledger in sync with the doctor's findings without ever duplicating a problem — and to detect *inversions* (a problem marked resolved whose condition still fires).
- **`experiment.outcomes`**: The load-bearing field. Pre-registering what each result *means* before looking at data is what prevents post-hoc rationalization; `/run-experiment` may only map observations onto these outcomes, never reinterpret. Ambiguous data means the experiment was under-designed — refine it, don't pick a winner.
- **`status`**: `ready` requires a complete `experiment` block; `resolved` requires `resolved_by` (a filed episode — resolution without evidence is not resolution). `dropped` records a problem judged not worth an experiment; say why in `resolution`.
- **`models`**: Bare ids of the models (or, for `contradiction` problems, entries) in tension. Indexed as edges, so `kb edges <model-id>` shows the open problems a model is entangled in.

---

## `_route.md` frontmatter

```yaml
---
type: route
folder: kb:/people/alex               # kb:/ path of this folder
title: Alex — manager
purpose: Notes related to my manager Alex (1:1s, feedback, projects)
last_indexed: 2026-05-05T14:30:00Z    # bumped by the librarian on any change to this folder's entries or subroutes
topics: [alex, management, 1to1]      # tags rolled up from this subtree
subroutes:
  - path: kb:/people/alex/projects/_route.md
    summary: Projects Alex owns or is involved in
entries:
  - id: 2026-05-05-1to1-alex-prep
    file: kb:/people/alex/2026-05-05-1to1-alex-prep.md
    summary: Prep notes for Q2 priorities discussion
related:                              # cross-links to other _route.md files. Cyclic ok.
  - kb:/processes/1to1/_route.md
---

# Alex

Free-form prose for things that don't fit the structured fields above.
The retriever reads frontmatter to traverse; it reads the prose only when WARM-loading the folder.
```

### Required fields

`type` (always `route`), `folder`, `title`, `purpose`, `last_indexed`. `topics`, `subroutes`, `entries`, `related` may be empty arrays but must be present.

### Field semantics

- **`folder`**: The `kb:/` path of this folder. Lets the librarian sanity-check that the file is where it claims to be.
- **`purpose`**: One sentence. Used by the routing agent during traversal to decide whether to descend.
- **`last_indexed`**: Bumped whenever entries or subroutes change. Used by the staleness pass to spot folders that haven't been touched in a long time.
- **`subroutes[].summary`**: One line per child folder. Routing agents read these to decide which branch to descend.
- **`entries[].summary`**: One line per entry. Routing agents read these to decide which entries warrant loading the full leaf summary.
- **`related`**: Cross-links to sibling/cousin folders the topic touches. Forms the cyclic graph.

---

## Invariants

- Every folder under `kb-data/` has exactly one `_route.md`.
- Every leaf — episodic entry, recipe, model, **or problem** — has its parent folder list it in that `_route.md`'s `entries`.
- `id` is unique across the whole kb-data tree (recipe, model, and problem ids share the same namespace as entry ids).
- All paths in frontmatter use the `kb:/` URI scheme. External URLs (`https://`) keep their normal form. Bare ids (in `supersedes` / `contradicts` / `superseded_by`) are not paths and need no prefix.
- All timestamps are ISO 8601 UTC.

The validation script (`kb-engine/scripts/validate.py`, slice 7) enforces these.

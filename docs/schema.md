# KB schema

Four file shapes live in `kb-data/`:

1. **Leaf entries** — one per filed conversation (episodic). Filename: `<YYYY-MM-DD>-<slug>.md`.
2. **Recipes** — reusable procedures distilled from one or more conversations (evergreen, `type: recipe`). Filename: `<slug>.md` (no date prefix). Live under `kb:/recipes/`.
3. **Models** — declarative claims about how something works (evergreen, `type: model`). Filename: `<slug>.md` (no date prefix). Live under `kb:/models/`.
4. **`_route.md`** — one per folder. The folder index. Used by the retriever to traverse without loading leaves.

All paths inside frontmatter use the **`kb:/` URI scheme**, rooted at the kb-data directory (e.g. `kb:/people/alex/_route.md`). Tooling resolves `kb:/` → `$KB_DATA_DIR/` at read time. The scheme makes it impossible to confuse with a filesystem path.

External references (Unblocked, Jira, Slack, code permalinks) keep their normal `https://` URLs unchanged. `id` references in `supersedes` / `contradicts` / `superseded_by` are bare ids, not paths.

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
sources:                              # external pointers (Unblocked / Jira / Slack / code permalinks). Optional.
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
- Every leaf — episodic entry, recipe, **or model** — has its parent folder list it in that `_route.md`'s `entries`.
- `id` is unique across the whole kb-data tree (recipe and model ids share the same namespace as entry ids).
- All paths in frontmatter use the `kb:/` URI scheme. External URLs (`https://`) keep their normal form. Bare ids (in `supersedes` / `contradicts` / `superseded_by`) are not paths and need no prefix.
- All timestamps are ISO 8601 UTC.

The validation script (`kb-engine/scripts/validate.py`, slice 7) enforces these.

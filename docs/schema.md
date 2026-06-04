# KB schema

Two file shapes live in `kb-data/`:

1. **Leaf entries** — one per filed conversation. Filename: `<YYYY-MM-DD>-<slug>.md`.
2. **`_route.md`** — one per folder. The folder index. Used by the retriever to traverse without loading leaves.

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
- **`summary`**: Load-bearing. The retriever decides HOT/WARM/COLD based on this. Keep it self-contained — a reader who only sees the summary should still understand what the entry is about.

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
- Every leaf entry's parent folder has the entry listed in its `_route.md`'s `entries`.
- `id` is unique across the whole kb-data tree.
- All paths in frontmatter use the `kb:/` URI scheme. External URLs (`https://`) keep their normal form. Bare ids (in `supersedes` / `contradicts` / `superseded_by`) are not paths and need no prefix.
- All timestamps are ISO 8601 UTC.

The validation script (`kb-engine/scripts/validate.py`, slice 7) enforces these.

# Splitting procedure (canonical)

When a leaf folder grows diverse, this procedure splits it into topic-coherent subfolders. Both the headless librarian (`librarian split <kb-path>`) and the `/split` slash command read this file.

---

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md` — read this before writing any frontmatter.
**Templates:** `$KB_ENGINE_DIR/templates/_route.md.template`.
**Validator:** `$KB_ENGINE_DIR/scripts/validate.py` — run after applying changes.

You will be told a target folder as a `kb:/` URI. Resolve it: `kb:/foo/bar` → `$KB_DATA_DIR/foo/bar`.

## Preconditions

1. Target folder exists and has a `_route.md`.
2. Target folder has at least 3 leaf entries directly in it (not counting entries in subfolders). If fewer, output exactly: `SKIPPED: only <N> entries in <kb-path>; need ≥3 to split.` Then stop.
3. Topics across entries are diverse enough to cluster. If a quick scan suggests they all genuinely belong together, output: `SKIPPED: entries cohere as one topic; no split warranted.` and stop.

## Procedure

### 1. Survey

Read the target folder's `_route.md`. Read each leaf entry's frontmatter (id, title, topics, summary, related). **Do not** read entry transcripts — too expensive, not needed for clustering. **Do not** descend into subfolders — only direct entries.

### 2. Cluster

Group entries into 2–4 clusters by topic coherence. Aim for clusters of roughly equal size when possible, but never sacrifice coherence for balance — better to have a 1-entry cluster if it genuinely doesn't fit elsewhere (which means: don't split it; either keep it in the parent or warrant its own subfolder if it's a clear fresh topic).

For each cluster, pick:
- A short hyphenated **slug** (lowercase, no spaces). It must not collide with any existing subfolder name in the parent.
- A **title** (≤ 60 chars).
- A one-sentence **purpose** for the subfolder's `_route.md`.
- A list of **topic tags** characterizing the cluster (3–6 tags, deduped from the entries' topics).

### 3. Output the plan

Before applying any changes, emit the plan in this exact form:

```
PLAN: split <kb-path> into <N> clusters

Cluster 1: <slug>
  Title: <title>
  Purpose: <purpose>
  Topics: <comma-separated>
  Entries:
    - <id> — <title>
    - ...

Cluster 2: <slug>
  ...

Unclustered (kept in parent): <ids or "(none)">
```

If the plan would be clearly bad (e.g. one cluster has all entries; clusters are nonsensical), instead output: `ABORTED: clustering produced low-quality result. <one-line reason>` and stop without writing anything.

### 4. Apply

For each cluster:

a. **Create the subfolder.** `mkdir <target>/<slug>/`.

b. **Write the new `_route.md`** at `<target>/<slug>/_route.md` using the template. Fill:
   - `type: route`
   - `folder: kb:/<rel>/<slug>` (rel = parent's path relative to kb-data root, with leading slash; or just `kb:/<slug>` if parent is root)
   - `title:` from cluster
   - `purpose:` from cluster
   - `last_indexed:` current ISO 8601 UTC
   - `topics:` from cluster
   - `subroutes: []`
   - `entries:` populated below
   - `related: []`

c. **Move each entry file** in this cluster from `<target>/<id>.md` to `<target>/<slug>/<id>.md`. Use `git mv` so history follows (run via Bash).

d. **For each moved entry, update its frontmatter:**
   - Bump `updated:` to now.
   - In `related:`, replace any reference to the old parent's `_route.md` (`kb:/<rel>/_route.md`) with the new subfolder's (`kb:/<rel>/<slug>/_route.md`). Leave other `related:` items alone.

e. **Add the entries to the new `_route.md`'s `entries:`** with id, file (the new `kb:/` path), and the entry's existing one-line summary (from its `summary:` field — take the first sentence or so, ≤ 100 chars).

### 5. Update the parent's `_route.md`

- Remove every moved entry from `entries:`.
- Add every new subfolder to `subroutes:` with its `kb:/<...>/_route.md` path and a one-line summary (= the new subfolder's purpose).
- Bump `last_indexed:` to now.
- Don't touch the parent's `topics:` for now — they'll get cleaned up by a later staleness pass.

### 6. Validate

Run `$KB_ENGINE_DIR/scripts/validate.py`. If it reports errors, the split is broken — output the validator errors and stop. Do NOT roll back automatically (Gregor uses `git status` / `git diff` to inspect; reverts are `git checkout -- .` or `git restore`).

### 7. Report

Output a final summary:

```
DONE: split <kb-path>
  Created <N> subfolders: <slug1>, <slug2>, ...
  Moved <M> entries
  Updated <K> related: references
  Parent _route.md re-indexed
  Validator: clean
```

## Constraints

- Use `git mv` not `mv` so history is preserved.
- Do not run `git commit`. Filing produces working-tree changes only; Gregor reviews and commits manually.
- Use ISO 8601 UTC timestamps with `Z` suffix.
- All paths in frontmatter use the `kb:/` scheme.
- Quote any list-item or scalar string containing an unquoted `:` followed by space — bare colons break YAML.
- If anything seems ambiguous (cluster boundaries, slug collisions, etc.), prefer the conservative option: smaller / fewer clusters, ABORTED over a wrong move.

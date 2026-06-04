# Dedup procedure (canonical)

Find pairs of entries that cover the same ground. Mark one as superseded (newest wins). Flag genuine contradictions in the active entry's `summary`.

This pass is **non-destructive**: it never deletes entries. It only updates frontmatter (`status`, `supersedes`, `superseded_by`, `contradicts`) and adds a contradiction note to `summary` when warranted.

---

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md`
**Validator:** `$KB_ENGINE_DIR/scripts/validate.py`

You will be told a scope: either a `kb:/` folder URI (dedup within that subtree, recursively) or `kb:/` (whole tree).

## Procedure

### 1. Survey

Read every leaf entry's frontmatter under the scope: id, title, topics, participants, sources, created, updated, status, summary. Skip entries already marked `status: superseded` or `status: archived`.

If fewer than 2 active entries are in scope, output: `SKIPPED: <N> active entries; need ≥2 to dedup.` and stop.

### 2. Find duplicate / overlapping pairs

For each pair of active entries, judge:

- **Same ground?** Do they cover the same Jira ticket, the same PR, the same 1:1 with the same person on the same date, the same incident, the same decision?
- **Contradiction?** Do they make conflicting claims?

Use frontmatter signals: shared `sources:` URLs (especially Jira/PR links), strong topic overlap, same participants, same date. Body content if needed.

Pair categories:
- **Same ground, no contradiction** — newer supersedes older.
- **Same ground, contradiction** — newer supersedes older, AND the contradiction gets flagged in the active one's summary.
- **Related but distinct** — leave alone. Add to `related:` if not already cross-linked? **Do not** modify `related:` in this pass; that's link-fix territory.
- **Unrelated** — leave alone.

Conservative bias: if you're not confident two entries cover the same ground, leave them alone. False positives here corrupt the KB silently.

### 3. Output the plan

```
PLAN: dedup under <kb-path> — <N> pair(s) flagged

Pair 1: 2026-05-05-foo  ←  2026-05-04-foo
  Same ground: <reason>
  Contradiction: yes/no
  Action: 2026-05-04-foo → status=superseded, superseded_by=2026-05-05-foo
          2026-05-05-foo → supersedes=[2026-05-04-foo]
          [if contradiction] + flag in 2026-05-05-foo.summary

Pair 2: ...
```

If no pairs are confidently duplicates, output: `SKIPPED: no high-confidence duplicate pairs found.` and stop.

If the LLM judgment is shaky on ≥30% of proposed pairs, output: `ABORTED: low confidence on too many pairs. <reason>` and stop without applying.

### 4. Apply

For each pair (older → superseded by newer):

a. **In the older entry:**
   - Set `status: superseded`
   - Set `superseded_by: <newer-id>` (bare id, not a path)
   - Bump `updated:` to now.
   - Do NOT delete the file. Do NOT modify the body.

b. **In the newer entry:**
   - Append `<older-id>` to `supersedes:` (if not already present).
   - Bump `updated:` to now.
   - **If there's a contradiction:** append `<older-id>` to `contradicts:` AND prepend a one-line note to the top of `summary:` explaining what changed: `"Note: supersedes <older-id> (was: <one-line of older claim>; now: <one-line of new claim>)."`

### 5. Update affected `_route.md` files

For each entry whose `status` changed to `superseded`, find its parent folder's `_route.md`. Update the matching entry in `entries[]`:

- The summary line gets a `[superseded]` prefix so retrieval can skip it cheaply.
- Bump the route's `last_indexed:`.

Do not remove the entry from `entries[]` — superseded ≠ archived. Retrieval skips by status field, not by absence.

### 6. Validate

Run `$KB_ENGINE_DIR/scripts/validate.py`. Surface any errors.

### 7. Report

```
DONE: dedup under <kb-path>
  Pairs processed: <N>
  Entries marked superseded: <M>
  Contradictions flagged: <K>
  Validator: clean
```

## Constraints

- Never delete entries. Mark, don't destroy.
- `supersedes` / `superseded_by` / `contradicts` use bare ids, never `kb:/` paths.
- Always run validator at the end.
- Newest-wins is the default. If two entries have identical timestamps, prefer the one with more sources, more decisions, more body content — but flag in the report (`Tied timestamp: kept <id>; <reason>`).
- Do not run `git commit`. Working-tree changes only.

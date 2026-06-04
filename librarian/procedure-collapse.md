# Collapse procedure (canonical)

Inverse of split. When a folder has subfolders that no longer warrant their own existence — too few entries, topic fully subsumed by parent — collapse them back into the parent.

This procedure operates on a **parent folder**. It looks at the parent's direct subfolders (one level down only) and decides which (if any) should collapse.

---

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md`
**Validator:** `$KB_ENGINE_DIR/scripts/validate.py` — run after applying changes.

You will be told a target parent folder as a `kb:/` URI.

## Procedure

### 1. Survey

Read the target folder's `_route.md`. For each subroute it lists, read that subfolder's `_route.md` and the frontmatter of every entry in it. Note: only direct entries, do not descend further.

If the target has fewer than 2 subfolders, output: `SKIPPED: <kb-path> has <N> subfolders; nothing to collapse.` and stop.

### 2. Decide collapse candidates

For each subfolder, consider whether it should collapse into the parent. Strong indicators *for* collapsing:

- Subfolder has only 1 entry (rarely justifies a dedicated folder)
- Subfolder's topics are a subset of the parent's topics, and there's no clear reason to keep them separate
- Subfolder's purpose is essentially restated by an entry's title (no real grouping value)

Strong indicators *against* collapsing:

- Subfolder has ≥3 entries and a coherent shared theme
- Subfolder is a known organizational unit (a person, a repo, a project) that will accumulate more entries
- Sibling subfolders mix different real domains

When unsure, prefer NOT collapsing. The split pass can always re-create structure later if needed.

If no subfolder is a good candidate, output: `SKIPPED: no subfolders worth collapsing under <kb-path>.` and stop.

### 3. Output the plan

```
PLAN: collapse <N> subfolder(s) under <kb-path>

Collapse: <subfolder-slug>
  Reason: <one-line>
  Entries to move up: <id>, <id>, ...

Collapse: <subfolder-slug>
  ...

Keep: <subfolder-slug> — <one-line reason>
[list any subfolders considered but kept]
```

If the proposed collapses would produce a parent folder with too many entries (>15) or a confused mix, output: `ABORTED: collapse would over-flatten parent. <reason>` and stop without applying.

### 4. Apply

For each subfolder being collapsed:

a. **Move every entry up** into the parent folder using `git mv` (history-preserving). Source: `<parent>/<sub-slug>/<id>.md`. Destination: `<parent>/<id>.md`.

b. **Update each moved entry's frontmatter:**
   - Bump `updated:` to now (ISO 8601 UTC).
   - In `related:`, replace any reference to the collapsing subfolder's `_route.md` (`kb:/<...>/<sub-slug>/_route.md`) with the parent's (`kb:/<...>/_route.md`). Other `related:` items unchanged.

c. **Delete the subfolder's `_route.md`** (`git rm`), then `rmdir` the now-empty subfolder. If anything else is in the subfolder (shouldn't be), abort and surface what remains.

### 5. Update parent's `_route.md`

- Remove every collapsed subfolder from `subroutes:`.
- Add every moved entry to `entries:` with id, file (the new `kb:/` path), and a one-line summary (≤ 100 chars; pull the first sentence of the entry's `summary:` field).
- Bump `last_indexed:` to now.

### 6. Validate

Run `$KB_ENGINE_DIR/scripts/validate.py`. If errors, surface them and stop — Gregor reverts via `git restore .`.

### 7. Report

```
DONE: collapse under <kb-path>
  Collapsed <N> subfolder(s): <slug1>, <slug2>, ...
  Moved <M> entries up to parent
  Updated <K> related: references
  Parent _route.md re-indexed
  Validator: clean
```

## Constraints

- Use `git mv` and `git rm` (history preservation).
- Do not run `git commit`.
- All paths in frontmatter use `kb:/` scheme; ISO 8601 UTC for timestamps.
- Quote list-items containing unquoted `:` (YAML safety).
- Conservative bias: when in doubt, KEEP the subfolder rather than collapse it. Collapsing is harder to reverse than keeping.

# Filing procedure (canonical)

This is the single source of truth for how a conversation gets filed into Gregor's KB. Both `/file-this` (live in a Claude Code session) and the headless librarian script (slice 2 onward, fired by the SessionEnd hook) read this file and follow it.

---

**KB root:** `$KB_DATA_DIR`
**Schema contract:** `$KB_ENGINE_DIR/docs/schema.md` — read it before writing any frontmatter, and follow it exactly.
**Templates:** `$KB_ENGINE_DIR/templates/entry.md.template` and `_route.md.template`.

You will be told whether the conversation to file is:
- **The current session's context** (when invoked via `/file-this`), or
- **A transcript on disk** at a path you'll be given (when invoked headlessly). In that case, Read the file first; it is JSONL with one message per line.

You may also be given an optional one-line hint about placement.

## Procedure

1. **Distill the conversation.** Identify:
   - Short title (≤ 70 chars)
   - Participants (default: just `gregor`)
   - 3–6 topic tags — **normalize each against the controlled vocabulary** in `$KB_DATA_DIR/_topics.yaml`: if a tag matches a canonical term's alias, use the canonical form. Do NOT merge a tag whose meaning differs from a `polysemous` term that shares its spelling (e.g. `backend`); prefer the more specific canonical the file suggests (`model-generation`, `routing`). If a genuinely new concept has no canonical, use a clean new tag (and it can be added to the vocabulary later).
   - Any explicit decisions made
   - Any open questions left dangling
   - A two-paragraph summary suitable for the WARM tier (someone reading only this should know what the entry is about)
   - Any external sources mentioned (Unblocked / Jira / Slack / code permalinks)

2. **Pick the placement folder.** Spawn an Explore subagent (or do it inline if the tree is small) to traverse `_route.md` from `$KB_DATA_DIR/_route.md` downward:
   - At each `_route.md`, read its frontmatter only. Look at `purpose`, `topics`, `subroutes[].summary`, `entries[].summary`.
   - Descend into the subroute whose `purpose` and topics best match the conversation.
   - Stop when no subroute is a clear better fit. That's the placement folder.
   - If no subroute exists yet but the conversation is clearly about a new topic that warrants its own folder, create one (mkdir + new `_route.md` from the template). Prefer creating new folders over cramming unrelated entries into existing ones.

3. **Write the leaf entry.**
   - Filename: `<YYYY-MM-DD>-<slug>.md` where date is today UTC (`date -u +%Y-%m-%d`) and slug is lowercase, hyphenated, derived from the title.
   - Path: `<placement folder>/<filename>`.
   - Use the entry template. Fill every field. Required: `id`, `title`, `created`, `updated`, `status`, `summary`. Empty arrays/`null` fine for the rest, but the keys must be present.
   - `id` = `<YYYY-MM-DD>-<slug>` (matches filename without extension).
   - `created` = current ISO 8601 UTC timestamp. `updated` = same.
   - **Set `recipe_candidate`** (auto-flag for the recipe mining pass): `true` when this conversation looks like a *reusable procedure* — it composed **≥3 distinct tools/data sources** (DB, Jira, Slack, codebase, k8s, Datadog, the KB, web) AND reached a **repeatable** outcome (a method you'd run again), especially if it used words like recipe/playbook/runbook/recurring. A one-off investigation, a single decision, or a 1:1 note is `false`. This is a cheap hint, not a commitment — it just tells `/mine-recipes` where to look. Do NOT create the recipe here; `/extract-recipe` and the mining pass do that.
   - Below frontmatter, paste a faithful transcript of the conversation. Do not summarize the transcript — the `summary` field already does that. The transcript is the HOT-tier payload.

4. **Update the parent `_route.md`.**
   - Add the new entry to `entries:` with its `id`, `file` (`kb:/` URI, e.g. `kb:/projects/kb/2026-05-05-foo.md`), and a one-line summary (≤ 100 chars).
   - Bump `last_indexed` to now.
   - If you created any new folders along the way, add them to the parent's `subroutes:` and bootstrap each new folder's `_route.md` from the template.

5. **Bubble up.** For every ancestor folder back to root:
   - Update `last_indexed` to now.
   - If the entry introduces a topic not already in the ancestor's `topics`, append it (deduped). Only add tags that genuinely characterize the subtree, not every leaf-level tag.
   - Don't touch `subroutes` or `entries` of ancestors — those only list direct children.

6. **Normalize topics (deterministic pass).** After writing, run the audit script so the new entry's tags are canonicalized even if step 1's judgment missed something:
   ```bash
   $KB_ENGINE_DIR/scripts/audit-topics.py --fix
   ```
   It rewrites only `topics:` lines and is idempotent (a no-op once the tree is clean). Note any polysemy warnings it prints — they are not auto-changed and may need a manual, more-specific tag.

7. **Report back.** Output a short summary:
   - Where the entry was filed (full path).
   - Any new folders created.
   - The entry's `id`, `topics`, and one-line summary.

## Constraints

- Do not invent participants or sources. If you don't know, leave the field empty.
- Do not add `contradicts:` entries on the first pass — that's a later slice.
- All paths in frontmatter use the `kb:/` URI scheme. The kb-data filesystem root is `$KB_DATA_DIR` but inside frontmatter that's `kb:/`. External URLs (`https://...`) keep their normal form. Bare ids (in `supersedes` / `contradicts`) need no prefix.
- Use ISO 8601 UTC for all timestamps. Append `Z`.
- Quote any list-item or scalar string that contains an unquoted `:` followed by space (e.g. mentions of `secrets: passthrough`, `key: value` inside prose). Bare colons break YAML parsing. Wrap the whole string in double quotes; PyYAML handles internal apostrophes and special chars fine inside double quotes.
- If a hint is provided about placement, prefer it over your own routing decision unless it would clearly misfile the entry.
- Normalize topics against `_topics.yaml` (step 1). After filing a batch you can sanity-check the whole tree with `kb-engine/scripts/audit-topics.py` (report) or `--fix` (rewrite drift in place).
- Do not run `git commit`. Filing produces working-tree changes only; Gregor reviews and commits manually.

# Filing procedure (canonical)

This is the single source of truth for how a conversation gets filed into Gregor's KB. Both `/file-this` (live in a Claude Code session) and the headless librarian script read this file and follow it.

---

**KB root:** `$KB_DATA_DIR`
**Schema contract:** `$KB_ENGINE_DIR/docs/schema.md` — read it before writing any frontmatter, and follow it exactly.
**Templates:** `$KB_ENGINE_DIR/templates/entry.md.template` and `_route.md.template`.
**CLI:** `$KB_ENGINE_DIR/scripts/kb` — does ALL route bookkeeping mechanically. You write the leaf; it does the rest.

You will be told whether the conversation to file is:
- **The current session's context** (when invoked via `/file-this`), or
- **A transcript on disk** at a path you'll be given (when invoked headlessly). In that case, Read the file first; it is JSONL with one message per line.

You may also be given an optional one-line hint about placement.

## Procedure

You have exactly three judgment steps (1–3) and one mechanical step (4).

1. **Distill the conversation.** Identify:
   - Short title (≤ 70 chars)
   - Participants (default: just `gregor`)
   - 3–6 topic tags — **normalize each against the controlled vocabulary** in `$KB_DATA_DIR/_topics.yaml`: if a tag matches a canonical term's alias, use the canonical form. Do NOT merge a tag whose meaning differs from a `polysemous` term that shares its spelling (e.g. `backend`); prefer the more specific canonical the file suggests (`model-generation`, `routing`). If a genuinely new concept has no canonical, use a clean new tag (and it can be added to the vocabulary later).
   - Any explicit decisions made
   - Any open questions left dangling
   - A two-paragraph summary suitable for the WARM tier (someone reading only this should know what the entry is about)
   - Any external sources mentioned (Unblocked / Jira / Slack / code permalinks)

2. **Pick the placement folder.** Run `$KB_ENGINE_DIR/scripts/kb routes --compact` (one Bash call, a few thousand tokens) and pick the folder whose purpose and entries best match the conversation. If the session's ambient `<kb-ambient-index>` is already in context, use that instead — no need to re-emit it.
   - If no existing folder fits and the conversation is clearly about a new topic that warrants its own folder: `mkdir` it and create its `_route.md` from the template, filling **only** `type`, `folder`, `title`, `purpose` (one good sentence — it's hand-curated forever) and empty `topics/subroutes/entries/related`. Prefer creating new folders over cramming unrelated entries into existing ones.
   - If a hint was provided, prefer it over your own routing decision unless it would clearly misfile the entry.

3. **Write the leaf entry.**
   - Filename: `<YYYY-MM-DD>-<slug>.md` where date is today UTC (`date -u +%Y-%m-%d`) and slug is lowercase, hyphenated, derived from the title.
   - Path: `<placement folder>/<filename>`.
   - Use the entry template. Fill every field. Required: `id`, `title`, `created`, `updated`, `status`, `summary`. Empty arrays/`null` fine for the rest, but the keys must be present.
   - `id` = `<YYYY-MM-DD>-<slug>` (matches filename without extension).
   - `created` = current ISO 8601 UTC timestamp. `updated` = same.
   - **Set `recipe_candidate`** (auto-flag for the recipe mining pass): `true` when this conversation looks like a *reusable procedure* — it composed **≥3 distinct tools/data sources** (DB, Jira, Slack, codebase, k8s, Datadog, the KB, web) AND reached a **repeatable** outcome (a method you'd run again), especially if it used words like recipe/playbook/runbook/recurring. A one-off investigation, a single decision, or a 1:1 note is `false`. This is a cheap hint, not a commitment — it just tells `/mine-recipes` where to look. Do NOT create the recipe here; `/extract-recipe` and the mining pass do that.
   - Below frontmatter, paste a faithful transcript of the conversation. Do not summarize the transcript — the `summary` field already does that. The transcript is the HOT-tier payload.

4. **Sync.** One command does everything that used to be manual bookkeeping (parent `entries[]`, new-folder `subroutes[]`, `last_indexed` bumps, topic normalization, search-index refresh):
   ```bash
   $KB_ENGINE_DIR/scripts/kb sync
   ```
   Read its output: note any topic-polysemy warnings (they are not auto-changed and may need a manual, more-specific tag). Do NOT hand-edit any `_route.md` entries/subroutes/last_indexed — `kb sync` owns those now. The derived one-line entry summary in the route is taken from your leaf `summary`'s first sentence; if you can write a sharper ≤100-char one-liner, you may edit it in the route afterwards (it is preserved on future syncs).

5. **Test the models** (the theory layer's empirical loop — cheap, skip only if `kb:/models/` doesn't exist). Read the frontmatter of every non-superseded model under `kb:/models/` (`statement`, `predictions`, `evidence_for`, `refuted_by`) and compare against the entry you just filed. Check for refutation FIRST — one counterexample outweighs any amount of corroboration:
   - The new episode **contradicts the statement or a prediction** → append the entry id to `refuted_by`, bump `updated:`, and flag it in your report — do NOT silently flip status to `refuted`; Gregor decides whether the model dies or gains a boundary condition.
   - The new episode **matches a prediction** → append the entry id to that model's `evidence_for` (never to a model whose `derived_from` already contains it — grounding isn't corroboration), bump `updated:`. If this is the first later episode to test it, flip `status: hypothesis → corroborated` — corroborated means *survived a test*, never proven; a future counterexample still kills it.
   - Neither → move on. Most filings touch no model.
   If you edited any model, re-run `kb sync`.

6. **Report back.** Output a short summary:
   - Where the entry was filed (full path).
   - Any new folders created.
   - The entry's `id`, `topics`, and one-line summary.
   - Any model confirmations/refutations from step 5 (`<model-id>: confirmed by this entry` / `REFUTATION FLAGGED — review <model-id>`).

## Constraints

- Do not invent participants or sources. If you don't know, leave the field empty.
- Do not add `contradicts:` entries on the first pass — that's a later slice.
- All paths in frontmatter use the `kb:/` URI scheme. The kb-data filesystem root is `$KB_DATA_DIR` but inside frontmatter that's `kb:/`. External URLs (`https://...`) keep their normal form. Bare ids (in `supersedes` / `contradicts`) need no prefix.
- Use ISO 8601 UTC for all timestamps. Append `Z`.
- Quote any list-item or scalar string that contains a `:` followed by space, **or a `#`** (e.g. `PR #140`, mentions of `key: value` inside prose). Bare colons break YAML parsing; an unquoted ` #` silently truncates the value as a comment. Wrap the whole string in double quotes.
- Do not run `git commit`. Filing produces working-tree changes only; Gregor reviews and commits manually.

# Recipe extraction procedure (canonical)

Single source of truth for distilling a **reusable procedure** ("how we do X") into a recipe
under `kb:/recipes/`. Both `/extract-recipe` (live in a session) and the headless mining pass
(slice 2) read this file and follow it.

---

**KB root:** `$KB_DATA_DIR`
**Schema contract:** `$KB_ENGINE_DIR/docs/schema.md` — read the **Recipe frontmatter** section before writing any frontmatter, and follow it exactly.
**Template:** `$KB_ENGINE_DIR/templates/recipe.md.template`.
**Tools vocabulary:** `$KB_DATA_DIR/_tools.yaml` (normalize the `tools:` field against it).
**Topics vocabulary:** `$KB_DATA_DIR/_topics.yaml` (normalize `topics:` as usual).

You will be told the **source** of the recipe:
- **The current session's context** (when invoked via `/extract-recipe` with no id), or
- **A named episodic entry id** (or a path to one) to distill, or
- **A set of entries** the mining pass clustered as the same recurring procedure.

You may also be given an optional one-line hint about the recipe's name or scope.

## What makes something a recipe

A recipe is worth extracting when the work is **repeatable** — you (or a teammate) will do this
shape of thing again. Signals: it combined several tools/data sources (DB, Jira, Slack, code,
k8s, Datadog, KB) with glue between them; it reached a reusable outcome; it has gotchas worth
not re-learning. A one-off investigation with no reuse value is NOT a recipe — file it as a
normal entry instead. When in doubt, ask the user.

## Procedure

1. **Distill the procedure** (not the episode). Separate the *method* from the *instance*:
   - **Title** (≤ 70 chars) — names the procedure, not a date.
   - **`when_to_use`** — the trigger. Describe the *situation* you'd be in when you reach for
     this, in the words you'd use to recognize it. This is what `/start` matches against.
   - **`inputs`** — the parameters the procedure is templated on (e.g. `window_start`, `today`,
     `target_id`). What changes run-to-run.
   - **`steps`** — a concise ordered outline, one line each (the WARM scan). The runnable detail
     goes in the body, not here.
   - **`tools`** — every skill / slash command / data source the procedure composes. **Normalize
     each against `_tools.yaml`**: map aliases to the canonical token; respect the polysemy guard.
     A genuinely new tool with no canonical gets a clean new token (add it to the vocab later).
   - **`topics`** — 2–4 tags, normalized against `_topics.yaml` as in the filing procedure.
   - **`summary`** — two-paragraph WARM summary: what the procedure achieves and its shape,
     including the load-bearing gotchas.
   - The **body** — the full step-by-step: exact commands, queries, output structure, gotchas,
     and pointers to the skills/commands it composes. This is the HOT payload, loaded when the
     recipe is actually run. Keep run-specific data (a particular date's results, specific ticket
     numbers) OUT of the recipe — that belongs in the source episodic entry.

2. **Set provenance.** `derived_from` = the bare ids of the episodic entries this was distilled
   from. If extracting from the live session, the recipe may have no source entry yet — leave
   `derived_from: []` and suggest the user `/file-this` the session so it can be linked.

3. **Check for an existing recipe.** Before writing, scan `kb:/recipes/` (read `_route.md` and the
   `when_to_use`/`summary` of existing recipes). If one already covers this procedure:
   - **Refine it in place** — improve the steps/gotchas, bump `updated`, append the new source id
     to `derived_from`. Do NOT create a near-duplicate.
   - Only `supersedes` an existing recipe when the method genuinely changed (set both `supersedes`
     on the new one and `superseded_by` + `status: superseded` on the old).

4. **Check for skill graduation.** If the procedure is stable and deterministic enough to be a
   Claude Code skill — and especially if a skill *already implements it* end-to-end — note this.
   Set `skill:` to the skill name if one exists.
   If none exists but the recipe is a strong candidate, flag it for the user; do NOT scaffold a
   skill automatically.

5. **Write the recipe file.**
   - Filename: `<slug>.md` — slug only, **no date prefix**. Path: `$KB_DATA_DIR/recipes/<slug>.md`
     (or a subfolder of `recipes/` if the cookbook has grown topic-coherent subfolders).
   - `id` = `<slug>` (matches filename stem).
   - Use the recipe template. Fill every field; required keys must be present (empty/`null` ok
     for the rest). `created` = `updated` = current ISO 8601 UTC (`date -u +%Y-%m-%dT%H:%M:%SZ`).
   - `last_verified` = when the procedure was last actually run end-to-end OK (the source entry's
     date is a good value if you're distilling a worked run); else `null`.
   - `status` = `active` when you're confident it's correct; `draft` when proposed/unverified
     (the default for mining-pass output awaiting review).

6. **Update `kb:/recipes/_route.md`.** Add the recipe to `entries:` (`id`, `file` kb:/ URI,
   one-line summary ≤ 100 chars). Bump `last_indexed`. If you created a new `recipes/` subfolder,
   add it to `subroutes:` and bootstrap its `_route.md` from the route template.

7. **Validate.** Run the schema check and fix anything it flags:
   ```bash
   $KB_ENGINE_DIR/scripts/validate.py
   ```

8. **Report back.** Output: where the recipe was filed, its `id`, `when_to_use`, `tools`,
   `derived_from`, whether it refined/superseded an existing recipe, and any skill-graduation flag.

## Constraints

- Keep the *method* in the recipe and the *instance* in the episodic entry. A recipe with a
  specific date's results baked in is a smell.
- Normalize `tools` against `_tools.yaml` and `topics` against `_topics.yaml`.
- All frontmatter paths use the `kb:/` scheme; external URLs keep `https://`; `derived_from` /
  `supersedes` / `superseded_by` are bare ids. ISO 8601 UTC timestamps, `Z` suffix.
- Quote any scalar/list-item string containing an unquoted `:` followed by space (YAML safety).
- Do NOT run `git commit`. Extraction produces working-tree changes only; Gregor reviews and commits.
- Do NOT auto-generate Claude Code skills. Flag graduation candidates; the human writes the skill.

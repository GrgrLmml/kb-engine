# Recipe mining procedure (canonical)

A periodic housekeeping pass that reads the **summary layer** of the KB (cheap — route
one-liners + leaf `summary` fields, no transcripts), spots **recurring procedures** that aren't
yet captured as recipes, and *proposes* them. It also scans existing recipes for **skill
graduation** candidates. It never writes a recipe silently — it outputs a plan, and on apply it
mints recipes as `status: draft` for Gregor to review and verify.

Read alongside `$KB_ENGINE_DIR/librarian/procedure-extract-recipe.md` — that procedure is how
each approved candidate actually gets written. This pass finds *what* to extract; that one does
the writing.

---

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md` (read the Recipe section)
**Tools vocab:** `$KB_DATA_DIR/_tools.yaml`
**Validator:** `$KB_ENGINE_DIR/scripts/validate.py`

You will be told a scope: a `kb:/` folder URI (mine within that subtree) or `kb:/` (whole tree).

## Procedure

### 1. Survey (summary layer only — stay cheap)

- Read every `_route.md` under the scope (frontmatter) and every leaf entry's frontmatter
  (`id`, `title`, `topics`, `summary`, `created`, `status`, `sources`, `recipe_candidate`).
  Do NOT read transcript bodies in this step — the summaries are the signal.
- **Prioritize flagged entries.** `grep -rl 'recipe_candidate: true' $KB_DATA_DIR` gives the
  entries filing already marked as procedural. Start there.
- Read existing recipes under `kb:/recipes/` (`id`, `when_to_use`, `summary`, `tools`,
  `derived_from`, `status`). You need these to avoid re-proposing what already exists.

Skip entries with `status: superseded` or `archived`.

### 2. Cluster recurring procedures

Group entries that describe the **same repeatable method** — not the same topic, the same
*method*. Signals:

- The summary describes a sequence of actions over tools/data sources ("swept Jira + Slack +
  Datadog", "ran the JQL queries, then…", "built the report by…").
- Explicit recurrence language: recipe, playbook, runbook, recurring, "re-use each cycle",
  "every week", "the method".
- Several entries that are clearly instances of one cadence (e.g. multiple weekly sprint-report
  preps, multiple catch-up briefings) — the *cadence* is the recipe.
- A single `recipe_candidate: true` entry that is strongly procedural on its own.

A candidate is **either**: a cluster of ≥2 entries running the same method, **or** a single
strongly-procedural flagged entry whose method is reusable.

### 3. Classify each candidate against existing recipes

For each candidate, check `kb:/recipes/`:

- **Already covered** by an active recipe with overlapping `when_to_use` → if the candidate adds
  a new source instance, mark it **REFINE** (append the entry id to that recipe's `derived_from`,
  and improve its steps/gotchas if the instance taught something new). Otherwise skip silently.
- **Not covered** → mark it **NEW** (mint a draft recipe).

Conservative bias: when unsure whether two entries are the same method, do NOT cluster them.
A spurious recipe is worse than a missed one.

### 4. Skill-graduation scan (existing recipes)

Separately, scan **active** recipes (`status: active`, not already pointing at a `skill:`):
flag any that are good candidates to graduate into a Claude Code skill — i.e. the steps are
**deterministic** (could be scripted), the recipe has been **verified** (`last_verified` set and
recent), and it's run often enough to be worth automating. Report these; do NOT write skills.

### 5. Output the plan

```
PLAN: mine-recipes under <kb-path>

NEW (mint as draft):
  - <proposed-slug>  ← derived_from: [<id>, <id>, ...]
      when_to_use: <one line>
      tools: <normalized list>
      why: <what recurring method this captures>

REFINE (update existing recipe):
  - <recipe-id>  + source <entry-id>
      change: <append derived_from / what gotcha to add>

GRADUATION CANDIDATES (report only — no writes):
  - <recipe-id> → consider a skill: <why it's deterministic + verified>
```

If no NEW/REFINE candidates cross the confidence bar, output `SKIPPED: <reason>` (still print any
graduation candidates) and stop. If judgment is shaky on ≥30% of proposed candidates, output
`ABORTED: <reason>` and write nothing.

### 6. Apply

- For each **NEW** candidate: follow `procedure-extract-recipe.md` to write the recipe, with
  `status: draft` and `derived_from` set to the cluster's entry ids. Drafts signal "proposed,
  not yet verified by Gregor."
- For each **REFINE**: edit the existing recipe in place — append the source id to
  `derived_from`, fold in any new gotcha, bump `updated:`. Do not duplicate.
- Add every new recipe to `kb:/recipes/_route.md` `entries:` and bump its `last_indexed:`.
- Do NOT change `recipe_candidate` on source entries (leave the breadcrumb).

### 7. Validate + report

Run `$KB_ENGINE_DIR/scripts/validate.py`. Then:

```
DONE: mine-recipes under <kb-path>
  New draft recipes: <N>   (<slug>, <slug>, ...)
  Recipes refined:   <M>
  Graduation candidates flagged: <K>
  Validator: clean
  Next: review the drafts, verify each procedure, flip status draft→active.
```

## Constraints

- Summary layer only in the survey — do not load transcripts to mine. Read a transcript only if
  you must, and only for a candidate you're about to write.
- New recipes are `status: draft` until Gregor verifies them. Never mint `active` from mining.
- Normalize `tools` against `_tools.yaml`, `topics` against `_topics.yaml`.
- Never delete or supersede an existing recipe in this pass — propose, don't overwrite. (Recipe
  dedup/supersede is a deliberate `/extract-recipe` action, not an automated one.)
- Do NOT auto-generate skills. Graduation is report-only.
- Do NOT run `git commit`. Working-tree changes only; Gregor reviews and commits.

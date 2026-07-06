# kb-engine — a personal, LLM-managed knowledge base

This repo is the **engine** for a personal knowledge base: slash commands, a filing
procedure, a schema validator, a topic-normalization vocabulary, and lifecycle hooks.
Your KB **content** lives separately in a `kb-data/` directory (created on install).

## First-time setup (do this)

If the commands below aren't working yet, this checkout hasn't been installed. Run:

```sh
./install.sh
```

It will: check dependencies (`git`, `uv`, `python3`), create an empty `kb-data/`,
symlink the slash commands into `~/.claude/commands/`, write `KB_ENGINE_DIR` and
`KB_DATA_DIR` into `~/.claude/settings.json`, register the SessionEnd
topic-normalization hook, and install the git pre-commit validator. It prompts before
editing `~/.claude/settings.json`, is re-runnable, and has `--uninstall`.

To keep your KB content somewhere other than `<repo>/kb-data`:
`./install.sh --kb-data /path/to/your/kb-data`.

**If you are Claude and the user just opened this repo:** if `$KB_DATA_DIR` is unset or
`~/.claude/commands/find.md` is missing, offer to run `./install.sh` for them. Otherwise
it's already installed — don't re-run it unprompted.

## How paths resolve

Everything is parameterized by two env vars, written into `~/.claude/settings.json` by
the installer and therefore present in every Claude Code session:

- `KB_ENGINE_DIR` — this repo (commands, scripts, hooks, docs).
- `KB_DATA_DIR` — where the KB content lives.

Scripts and hooks also self-resolve these from their own location if the env vars are
absent (e.g. the git pre-commit hook, which runs outside a Claude session). So nothing
is hardcoded to one machine.

## The `kb` CLI (use it — don't traverse by hand)

`$KB_ENGINE_DIR/scripts/kb` is the deterministic core. When working **on this repo or
with the KB**, prefer it over manual find/grep pipelines:

- `kb search <terms>` — ranked BM25 search (self-refreshing index). `--type recipe`, `--topic`, `--person`, `--all-status`, `--json`.
- `kb show <id>` / `kb show --path <id>` — resolve any id / `kb:/` URI / path.
- `kb edges <id>` — typed edges, forward and reverse.
- `kb routes [--compact|--deep]` — the route layer + BASELINE size metrics.
- `kb sync` — after writing any leaf: regenerates route `entries[]`/`subroutes[]`/`last_indexed`, normalizes topics, refreshes the index. Never hand-edit those route fields.
- `kb doctor` — broken refs, stale recipes, route drift.

A compact KB index is auto-injected into new sessions as `<kb-ambient-index>` (SessionStart hook). The `kb-recall` skill reaches into the KB proactively.

## Commands

Run any of these in a Claude Code session once installed:

- `/find <query>` — ranked search; pulls best matches to WARM tier, follows curated edges.
- `/ask <question>` — answer a question from the KB via the cheap `kb-researcher` subagent (Haiku reads the transcripts, main context gets only the distilled cited answer). The `kb-recall` skill takes this same route automatically for plain questions.
- `/load-kb [--deep] [query]` — load the whole index into context (high-recall baseline).
- `/file-this [hint]` — file the current conversation into the KB.
- `/jot <fact>` — capture a small durable fact in seconds (minimal leaf, no transcript).
- `/start <intent>` — bootstrap a session with relevant KB context.
- `/promote <id>` — load an entry's full transcript (HOT tier).
- `/extract-recipe [id|hint]` — distill a reusable procedure ("how we do X") into `kb:/recipes/`.
- `/mine-recipes [kb:/folder]` — mine the KB for recurring procedures, propose them as draft recipes, flag skill-graduation candidates.
- `/theorize [kb:/folder]` — the theory layer's growth pass: harvest open problems, conjecture explanatory models (falsifiable hard-to-vary claims, `kb:/models/`) through a criticism gate, chain model statements into derived conclusions, flag premise contradictions.
- `/criticize [model-id]` — the criticism pass: attack live models (hard-to-vary, consistency, counterexample sweep), conjecture rivals for lone hypotheses, emit the crucial-experiment queue.
- `/split` · `/collapse` · `/dedup` · `/tidy` — librarian housekeeping passes (`/tidy` also runs the recipe-mining pass).

## Layout

- `commands/` — slash commands (symlinked into `~/.claude/commands` by install).
- `skills/` — proactive skills (`kb-recall`), symlinked into `~/.claude/skills` by install.
- `agents/` — subagent definitions (`kb-researcher`: cheap read-only transcript extraction), symlinked into `~/.claude/agents` by install.
- `librarian/` — the canonical filing/split/collapse/dedup/extract-recipe/mine-recipes/theorize procedures.
- `scripts/` — `kb` (deterministic CLI: search/show/edges/routes/sync/doctor), `validate.py` (schema), `audit-topics.py` (topic normalization), `librarian` (headless).
- `hooks/` — `session-start.sh` (ambient index + open-problem queue), `normalize-topics.sh` (SessionEnd sweep + index refresh), `auto-recall.sh` (experimental, NOT registered by default), `pre-commit` (kb-data schema validator), `pre-commit-no-leaks` (ENGINE repo leak guard: blocks commits containing terms from the private `$KB_DATA_DIR/_banned-terms.txt` — this repo is public, KB content must never leak in), `session-end.sh` (legacy auto-file, off by default).
- `docs/schema.md` — the frontmatter contract (leaf entries, recipes, routes). Read it before editing KB files.
- `docs/plan-day2.md` — the day-2 maturity plan (phases 1–3 shipped; phase 4 trigger-gated).
- `templates/` — starter files for new entries, recipes, routes, and the topic/tools vocabularies.

Recipes (`type: recipe`, under `kb:/recipes/`) are evergreen reusable procedures distilled from
conversations — see `docs/schema.md`. The `tools:` field is normalized against `kb-data/_tools.yaml`.
Models (`type: model`, under `kb:/models/`) are falsifiable, hard-to-vary claims — the KB's theory
layer, grown by conjecture and criticism (never induction): conjectured by `/theorize` from open
problems as `hypothesis`, attacked by `/criticize` (rivals + crucial experiments), corroborated or
refuted automatically as new episodes are filed (never "validated" — survival, not proof), chained
into `derived` conclusions at answer time (always labeled, always citing premise ids).

See `README.md` for deeper detail on the architecture and the schema.

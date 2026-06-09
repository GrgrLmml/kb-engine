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

## Commands

Run any of these in a Claude Code session once installed:

- `/find <query>` — search the KB; pulls best matches to WARM tier, follows curated edges.
- `/load-kb [--deep] [query]` — load the whole index into context (high-recall baseline).
- `/file-this [hint]` — file the current conversation into the KB.
- `/start <intent>` — bootstrap a session with relevant KB context.
- `/promote <id>` — load an entry's full transcript (HOT tier).
- `/extract-recipe [id|hint]` — distill a reusable procedure ("how we do X") into `kb:/recipes/`.
- `/mine-recipes [kb:/folder]` — mine the KB for recurring procedures, propose them as draft recipes, flag skill-graduation candidates.
- `/split` · `/collapse` · `/dedup` · `/tidy` — librarian housekeeping passes (`/tidy` also runs the recipe-mining pass).

## Layout

- `commands/` — slash commands (symlinked into `~/.claude/commands` by install).
- `librarian/` — the canonical filing/split/collapse/dedup/extract-recipe/mine-recipes procedures.
- `scripts/` — `validate.py` (schema), `audit-topics.py` (topic normalization), `librarian` (headless).
- `hooks/` — `normalize-topics.sh` (SessionEnd), `pre-commit` (validator), `session-end.sh` (legacy auto-file, off by default).
- `docs/schema.md` — the frontmatter contract (leaf entries, recipes, routes). Read it before editing KB files.
- `templates/` — starter files for new entries, recipes, routes, and the topic/tools vocabularies.

Recipes (`type: recipe`, under `kb:/recipes/`) are evergreen reusable procedures distilled from
conversations — see `docs/schema.md`. The `tools:` field is normalized against `kb-data/_tools.yaml`.

See `README.md` for deeper detail on the architecture and the schema.

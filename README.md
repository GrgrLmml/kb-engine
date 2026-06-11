# kb-engine

**A personal, LLM-managed knowledge base for Claude Code.** Conversations, decisions, and reusable procedures get distilled into a curated knowledge graph of plain markdown — and every new Claude session starts *already knowing what's in it*.

```
you: "I trust you are familiar with our Acme PoC?"
claude: [sees the entry in the ambient index, runs kb search — milliseconds]
        "Yes — filed three weeks ago. The scoping call was locked for Monday,
         the requirements brief is posted, and two questions are still open: ..."
```

No re-explaining context. No "let me search your files for a few minutes". No stale notes — entries supersede and contradict each other explicitly, and a validator keeps the graph sound.

![git clone, install.sh, then a Claude session recalling from the demo KB](demo/demo.gif)

*The session above runs against a small fictional corpus. Your KB starts empty — `install.sh` bootstraps it and the first `/file-this` plants the first entry.*

## Why not just CLAUDE.md, built-in memory, or SKILL.md files?

Those are great at what they do — kb-engine sits above them and fixes what they can't:

| | CLAUDE.md / auto-memory | static SKILL.md | **kb-engine** |
|---|---|---|---|
| Capacity | a few KB before it bloats every prompt | per-skill | unbounded corpus; only a ~4k-token index rides along |
| Structure | flat prose | flat prose | knowledge graph: folders + routes + typed edges (`related`, `supersedes`, `contradicts`) |
| Retrieval | always-loaded or gone | trigger-phrase match | ranked BM25 search (SQLite FTS5, ms), typed-edge expansion, tiered loading |
| Capture | passive, lossy | manual authoring | `/file-this` distills a whole conversation; `/jot` captures a fact in seconds |
| Lifecycle | grows stale silently | grows stale silently | `kb doctor` flags drift; `/tidy` splits, collapses, dedups; entries supersede each other |
| Procedures | — | static, you write them | `/extract-recipe` distills "how we do X" from real sessions; `/mine-recipes` finds recurring ones; mature recipes graduate *into* skills |
| Ownership | opaque store | files | plain markdown in a git repo you own, schema-validated on commit |

The one-line version: **built-in memory remembers facts about you; kb-engine runs an institutional memory** — searchable, curated, self-maintaining, with provenance.

## How it works

Three layers, each doing only what it's good at:

```
 ┌─ Ambient ────────────────────────────────────────────────┐
 │ SessionStart hook injects a compact KB index (~4k tokens)│
 │ + kb-recall skill: Claude reaches in unprompted          │
 ├─ Judgment (LLM) ─────────────────────────────────────────┤
 │ slash commands + librarian procedures: distill, place,   │
 │ re-rank, synthesize — never traverse, never bookkeep     │
 ├─ Deterministic core (scripts/kb) ────────────────────────┤
 │ SQLite FTS5, no server: search / show / edges / routes / │
 │ sync / doctor — milliseconds per call                    │
 └──────────────────────────────────────────────────────────┘
```

Context is loaded in tiers — **HOT** (full transcript), **WARM** (summaries and route indexes), **COLD** (on disk) — so a big corpus never crowds the window: the ambient index is the WARM map, and `/find` / `/promote` move things up the temperature scale on demand.

## Commands at a glance

| | Command | What it does |
|---|---|---|
| **Capture** | `/file-this` | distill the current conversation into the KB (entry + edges + routes) |
| | `/jot <fact>` | capture one durable fact in seconds, no transcript |
| | `/extract-recipe` | distill a reusable procedure ("how we do X") into `kb:/recipes/` |
| **Retrieve** | *(ambient)* | every session starts with the KB index; Claude recalls proactively |
| | `/find <query>` | ranked search → best matches into context, curated edges followed |
| | `/start <intent>` | bootstrap a session with everything relevant to what you're about to do |
| | `/promote <id>` | load an entry's full transcript (HOT tier) |
| | `/load-kb` | load the whole route layer (high-recall baseline) |
| **Maintain** | `/tidy` | split + collapse + dedup + recipe-mining passes |
| | `/mine-recipes` | find recurring procedures across the KB, propose draft recipes |
| | `kb doctor` | broken refs, stale recipes, route drift |

## Install

```sh
git clone <this repo> && cd kb-engine
./install.sh
```

`install.sh` checks dependencies (`git`, `uv`, `python3`), bootstraps an empty `kb-data/`, symlinks the slash commands into `~/.claude/commands/` and the `kb-recall` skill into `~/.claude/skills/`, writes `KB_ENGINE_DIR` and `KB_DATA_DIR` into `~/.claude/settings.json`, registers the hooks (SessionStart ambient index, SessionEnd topic normalization, PreToolUse permission hook so KB queries never hit a permission prompt), adds permission allow rules for the engine scripts plus `kb-data` as an additional working directory, and installs the git pre-commit validator. It prompts before editing `~/.claude/settings.json`, is **idempotent / re-runnable**, and supports `--uninstall`.

- Keep content elsewhere: `./install.sh --kb-data /path/to/kb-data`
- Skip the settings prompt: `./install.sh --yes`
- Remove all wiring (content untouched): `./install.sh --uninstall`

Then open a new Claude Code session (or run `/hooks` to reload) and try `/load-kb`.

### Path resolution (no hardcoded paths)

Everything is parameterized by two env vars, written into `~/.claude/settings.json` by the installer so they're present in every session: **`KB_ENGINE_DIR`** (this repo) and **`KB_DATA_DIR`** (your content). Scripts and hooks also self-resolve these from their own on-disk location when the env vars are absent (e.g. the git pre-commit hook, which runs outside a Claude session), so nothing is tied to one machine.

### Permissions (no confirmation fatigue)

Claude Code refuses to prefix-match allow rules against commands containing variable expansion (`$KB_ENGINE_DIR/...`), so plain allow rules never fire for KB commands. `hooks/allow-kb-query.sh` (PreToolUse, registered by install) closes the gap: it auto-allows a command when **every** segment is either a KB engine script (`scripts/kb`, `validate.py`, `audit-topics.py`) or a read-only file command (`cat`/`grep`/`sed -n`/`find`/...) whose only expansions are the two trusted KB vars — no redirection, no `sed -i`, no `find -delete`, no command substitution. Everything else falls through to the normal permission flow.

## Layout

- `CLAUDE.md` — what greets Claude when the repo is opened (points at `install.sh`).
- `install.sh` — the installer (global, idempotent, `--uninstall`).
- `docs/schema.md` — the frontmatter contract for leaf entries, recipes, and `_route.md` files. Read this first.
- `docs/plan-day2.md` — the day-2 maturity plan this architecture implements.
- `templates/` — starter files for new entries, recipes, routes, and the topic/tools vocabularies.
- `commands/` — Claude Code slash commands (`/file-this`, `/jot`, `/find`, `/load-kb`, `/start`, `/promote`, `/split`, `/collapse`, `/dedup`, `/tidy`, `/extract-recipe`, `/mine-recipes`).
- `skills/kb-recall/` — proactive-recall skill (symlinked into `~/.claude/skills` by install).
- `librarian/procedure-file.md` — canonical filing procedure shared by the slash command and the headless librarian script.
- `scripts/kb` — the deterministic CLI (see below). `scripts/validate.py` — schema validator. `scripts/audit-topics.py` — topic normalization. `scripts/librarian` — headless maintenance.
- `hooks/session-start.sh` — SessionStart ambient-index injection. `hooks/normalize-topics.sh` — SessionEnd topic sweep + index refresh. `hooks/allow-kb-query.sh` — PreToolUse permission hook (see above). `hooks/auto-recall.sh` — experimental per-prompt recall (NOT registered by default). `hooks/pre-commit` — schema validator gate. `hooks/session-end.sh` — legacy auto-file (off by default).

## The `kb` CLI

```sh
kb index            # build/refresh the FTS5 index (incremental; auto-runs before searches)
kb search <terms> [--type recipe] [--topic t] [--person p] [--all-status] [--json] [-n 10]
kb show <id|kb:/uri|path> [--path]
kb edges <id>       # typed edges, forward AND reverse ("what links here")
kb routes [--compact|--deep]   # route layer + BASELINE metrics; --compact is the ambient payload
kb reindex-routes [--dry-run]  # regenerate entries[]/subroutes[]/last_indexed from leaves
kb sync             # reindex-routes + audit-topics --fix + index — run after any filing
kb doctor           # broken refs, stale recipes, route drift
```

Route files stay half-curated: `purpose`, `related`, and the prose body are yours
(and the LLM's at filing time); `entries[]`, `subroutes[]`, and `last_indexed` are
derived data owned by `kb sync`. Hand-edited one-line entry summaries are preserved.

## Ambient context

`install.sh` registers a SessionStart hook (matcher `startup|clear`) that injects
`kb routes --compact` (~3–4k tokens today, hard-capped at ~15k) into every new
session as `<kb-ambient-index>`. Pause it with `touch $KB_DATA_DIR/.no-ambient`.

`hooks/auto-recall.sh` (UserPromptSubmit) goes further: BM25-search every prompt and
inject hits above a score threshold. It is experimental and **not registered by
default** — the registration snippet is in the file's header. Kill switch:
`touch $KB_DATA_DIR/.no-auto-recall`.

## Filing is manual

Filing happens only when you run `/file-this` in a session. There is **no SessionEnd auto-file**: the conversation is filed only when you explicitly ask.

The infrastructure for auto-filing is still in place (`hooks/session-end.sh` + librarian `file` mode + `.no-auto-file` marker logic) — dormant by default. To opt back in, add this `hooks` block to `~/.claude/settings.json`:

```json
"hooks": {
  "SessionEnd": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "$KB_ENGINE_DIR/hooks/session-end.sh"
        }
      ]
    }
  ]
}
```

When the hook is enabled, you can pause it without removing it by `touch kb-data/.no-auto-file` (delete the marker to re-enable).

## Logs

Every headless librarian run (split, collapse, dedup, or — if you re-enable the hook — file) writes to `kb-data/.librarian/log/<timestamp>-<session>-<mode>.md` (gitignored). Tail the most recent:

```sh
ls -t $KB_DATA_DIR/.librarian/log/ | head -1 | \
  xargs -I{} cat $KB_DATA_DIR/.librarian/log/{}
```

## Locking

`kb-data/.librarian.lock` is a directory created via atomic `mkdir`. If a stale lock survives a crash, the next librarian run detects the dead PID and clears it. If two librarians race, the second waits up to 30s then aborts (logs the abort).

## Architecture (short)

- **Knowledge graph.** Folders form a tree; `_route.md` files form a cyclic graph on top via `related` links.
- **Two file types.** Leaf entries (`<date>-<slug>.md`) hold filed conversations. `_route.md` indexes each folder so retrieval can traverse without loading leaves. Recipes (`type: recipe`, under `kb:/recipes/`) are evergreen procedures with `when_to_use` triggers.
- **HOT / WARM / COLD.** Main agent has HOT context (full transcript loaded), WARM (just the entry's summary or a folder's `_route.md`), or COLD (not loaded). Retrieval moves things up the temperature scale on demand.
- **Librarian.** Headless Claude run that files conversations, branches when a leaf grows too diverse, dedups, flags contradictions, and runs cleanup passes. One program, multiple modes.

See `docs/schema.md` for the frontmatter contract and `librarian/procedure-file.md` for the filing procedure.

### Schema validator

`scripts/validate.py` walks `kb-data/`, parses every `.md` file's YAML frontmatter, and enforces the schema: required fields, ISO 8601 UTC timestamps, `kb:/` URIs that resolve on disk, ids matching filenames, every leaf appearing in its parent route's `entries[]`, etc.

Self-contained via `uv run --script` (PEP 723) — no global PyYAML install needed; uv manages the dependency in a cached ephemeral venv.

```sh
# Manual run
$KB_ENGINE_DIR/scripts/validate.py

# Pre-commit hook in kb-data — installed by install.sh, or by hand:
ln -sf $KB_ENGINE_DIR/hooks/pre-commit \
       $KB_DATA_DIR/.git/hooks/pre-commit

# Skip in emergencies (don't make a habit of it):
git commit --no-verify
```

Validator output is one error per line, prefixed with the file's `kb:/` path. Exit code 1 on any error.

## Slice progress

- [x] Slice 1: schema + `/file-this` + `/find`
- [x] Slice 2: SessionEnd hook auto-file + locking + logging *(hook disabled by default — filing is now manual via `/file-this`)*
- [x] Slice 7: validation script + git pre-commit
- [x] Auto-routing at session start (`/start <intent>`)
- [x] Slice 3a: splitting (`/split kb:/folder`)
- [x] Slice 3b: collapse (`/collapse kb:/parent`) + dedup (`/dedup kb:/scope`)
- [x] `/tidy kb:/scope` — runs split + collapse + dedup in sequence
- [x] `/promote <id-or-path>` (slice 5 partial — `/demote` skipped; context is monotonic)
- [x] Recipe layer (`/extract-recipe`, `/mine-recipes`, `kb:/recipes/`, `_tools.yaml`)
- [x] Day-2 Phase 1: `kb` CLI + deterministic retrieval (`/find`/`/start` inline, no subagent)
- [x] Day-2 Phase 2: ambient index (SessionStart) + `kb-recall` skill + auto-recall (opt-in)
- [x] Day-2 Phase 3: `kb sync` filing + `/jot`
- [x] Slice 6 (partial): staleness via `kb doctor` (recipes, broken refs, route drift)
- [x] Permission hook (`allow-kb-query.sh`) — KB access without confirmation fatigue
- [ ] Day-2 Phase 4: hybrid semantic search — trigger: deep corpus ≳150–200k tokens (see `docs/plan-day2.md`)
- [ ] Scheduled `/tidy` + `kb doctor` (cron / scheduled agent)
- [ ] link-fix mode (when path-rewrite bugs surface)

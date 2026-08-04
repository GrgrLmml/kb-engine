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
| Capacity | a few KB before it bloats every prompt | per-skill | unbounded corpus; only a ~2-3k-token folder map rides along (O(folders), not O(entries)) |
| Structure | flat prose | flat prose | knowledge graph: folders + routes + typed edges (`related`, `supersedes`, `contradicts`) |
| Retrieval | always-loaded or gone | trigger-phrase match | hybrid search (BM25 ∪ local static embeddings, RRF-fused, ms, no server), typed-edge expansion, tiered loading, per-prompt auto-recall — quality proven by a built-in eval harness |
| Capture | passive, lossy | manual authoring | `/file-this` distills a whole conversation (`--bg`: in the background); `/jot` captures a fact in seconds; substantial unfiled sessions queue themselves for one-keystroke filing |
| Lifecycle | grows stale silently | grows stale silently | `kb doctor` flags drift; a nightly librarian validates, auto-commits, syncs, and rotates; entries supersede each other |
| Procedures | — | static, you write them | `/extract-recipe` distills "how we do X" from real sessions; `/mine-recipes` finds recurring ones; mature recipes graduate *into* skills |
| Reasoning | — | — | a Popperian theory layer: falsifiable models, rival conjectures, a durable experiment ledger, and `/run-experiment` to settle them with real observations |
| Ownership | opaque store | files | plain markdown in a git repo you own, schema-validated on commit |

The one-line version: **built-in memory remembers; kb-engine *resolves*.** Every other AI-memory system accumulates entries — this one also runs conjecture and criticism over them: models carry pre-registered crucial experiments in a durable ledger, a scheduled critic attacks the theory layer overnight, and the metric that matters is problems *closed*, not entries filed.

## How it works

Three layers, each doing only what it's good at:

```
 ┌─ Ambient ────────────────────────────────────────────────┐
 │ SessionStart: tiered payload — folder map always (~2-3k  │
 │ tokens), full entry lists for THIS repo's KB folders,    │
 │ problem-ledger + nightly-digest deltas                   │
 │ UserPromptSubmit: semantic auto-recall (calibrated to    │
 │ stay silent on irrelevant prompts)                       │
 ├─ Judgment (LLM) ─────────────────────────────────────────┤
 │ slash commands + librarian procedures: distill, place,   │
 │ re-rank, synthesize — never traverse, never bookkeep     │
 │ nightly: deterministic upkeep + a weekly headless critic │
 ├─ Deterministic core (scripts/kb) ────────────────────────┤
 │ SQLite FTS5 + local static embeddings (model2vec), no    │
 │ server: search / show / edges / routes / sync / doctor / │
 │ problems / eval / recall — milliseconds per call         │
 └──────────────────────────────────────────────────────────┘
```

Context is loaded in tiers — **HOT** (full transcript), **WARM** (summaries and route indexes), **COLD** (on disk) — so a big corpus never crowds the window: the ambient index is the WARM map, and `/find` / `/promote` move things up the temperature scale on demand.

Between WARM and HOT sits **delegated extraction**: for questions whose answer lives inside transcript bodies ("how did we trigger the recovery update last time?", "overview of my last 3 incidents"), a cheap read-only `kb-researcher` subagent (Haiku) reads the full transcripts in *its own* context and returns only the distilled, cited answer — the main window never pays for the transcripts. The `kb-recall` skill routes plain questions there automatically; `/ask` is the explicit entry point.

Above the episodes sits the **theory layer** (`kb:/models/`, `type: model`): falsifiable, hard-to-vary claims about how things work, each with a `statement` (the premise), `predictions` (testable consequences), and grounding/evidence/rival edges. It grows by **conjecture and criticism** (Popper/Deutsch), never induction — episodes can't speak; problems provoke guesses, and criticism kills the bad ones. `/theorize` harvests open problems and conjectures models to solve them, gating every candidate before minting (as `hypothesis`); filing tests each new episode against predictions (held → `corroborated`, *survived*, never proven; counterexample → flagged); models let the system *deduce* — chain two statements and derive a conclusion no transcript records, always labeled `derived` with its premise ids.

The part that makes it a *reasoning* tool rather than a belief store is the **resolve loop**. Open conflicts (undiscriminated rivals, refutation evidence, contradictions) become durable `type: problem` leaves in `kb:/problems/` — the **epistemic ledger**, reconciled deterministically from `kb doctor` findings by `kb problems scan`. `/criticize` attacks the live models and writes each surviving conflict's **pre-registered crucial experiment** into its ledger entry (`observation`, `where`, and an `outcomes` table stating what each result *means* — written before anyone looks at data, so results can't be rationalized after the fact). `/run-experiment` then executes one: it makes the observation with the session's real tools (observability, data warehouse, one Slack question), maps it onto the pre-registered outcomes, and — with the owner confirming — the loser goes `refuted` (or narrows via supersession), the winner gains corroboration, and the problem closes with a filed episode as evidence. The ambient index shows the ledger's counts and aging, so progress (and stalling) is visible; a weekly headless critic keeps designing experiments, but throttles itself while ≥6 sit unrun — criticism is generated at the pace of resolution, not faster.

## Commands at a glance

| | Command | What it does |
|---|---|---|
| **Capture** | `/file-this [--bg]` | distill the current conversation into the KB (`--bg`: background, keep working) |
| | `/jot <fact>` | capture one durable fact in seconds, no transcript |
| | `/extract-recipe` | distill a reusable procedure ("how we do X") into `kb:/recipes/` |
| **Retrieve** | *(ambient)* | every session starts with the KB index; Claude recalls proactively |
| | `/find <query>` | ranked search → best matches into context, curated edges followed |
| | `/ask <question>` | cheap subagent reads the transcripts, returns only the distilled cited answer |
| | `/start <intent>` | bootstrap a session with everything relevant to what you're about to do |
| | `/promote <id>` | load an entry's full transcript (HOT tier) |
| **Maintain** | `/tidy` | split + collapse + dedup + recipe-mining passes |
| | `/mine-recipes` | find recurring procedures across the KB, propose draft recipes |
| | `/theorize` | harvest problems, conjecture explanatory models through a criticism gate, chain them into derived conclusions |
| | `/criticize` | attack the live models: hard-to-vary checks, rival conjectures, pre-registered experiments into the ledger |
| | `/run-experiment` | execute one ready experiment with real tools; resolve the problem, settle the models |
| | `/graduate-recipe` | turn a proven recipe into a personal Claude Code skill |
| | `kb doctor` / `kb problems` | broken refs, stale recipes, route drift / the epistemic ledger |
| | *(nightly)* | validate, auto-commit kb-data, sync, doctor delta, ledger scan, digest — while you sleep |

## Install

```sh
git clone <this repo> && cd kb-engine
./install.sh
```

`install.sh` checks dependencies (`git`, `uv`, `python3`), bootstraps an empty `kb-data/`, symlinks the slash commands into `~/.claude/commands/`, the `kb-recall` skill into `~/.claude/skills/`, and the `kb-researcher` subagent into `~/.claude/agents/`, writes `KB_ENGINE_DIR` and `KB_DATA_DIR` into `~/.claude/settings.json`, registers the hooks (SessionStart tiered ambient payload, UserPromptSubmit semantic auto-recall, SessionEnd capture-candidate queue, PreToolUse permission hook so KB queries never hit a permission prompt) and — on macOS, after its own prompt — a nightly launchd librarian (validate, auto-commit kb-data, sync, doctor delta, ledger scan, log rotation, digest; weekly headless critic), adds permission allow rules for the engine scripts plus `kb-data` as an additional working directory, and installs the git pre-commit hooks: the schema validator in kb-data, and a **leak guard** in kb-engine itself that blocks any commit containing a term from the private `$KB_DATA_DIR/_banned-terms.txt` (the engine repo is public; your KB's names must never end up in it — and the banned list itself lives outside the repo so it never ships). It prompts before editing `~/.claude/settings.json`, is **idempotent / re-runnable**, and supports `--uninstall`.

- Keep content elsewhere: `./install.sh --kb-data /path/to/kb-data`
- Skip the settings prompt: `./install.sh --yes`
- Remove all wiring (content untouched): `./install.sh --uninstall`

Then open a new Claude Code session (or run `/hooks` to reload) and try `/find <something>`.

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
- `commands/` — Claude Code slash commands (`/file-this`, `/jot`, `/find`, `/ask`, `/start`, `/promote`, `/dedup`, `/tidy`, `/extract-recipe`, `/mine-recipes`, `/graduate-recipe`, `/theorize`, `/criticize`, `/run-experiment`).
- `skills/kb-recall/` — proactive-recall skill (symlinked into `~/.claude/skills` by install).
- `agents/kb-researcher.md` — cheap read-only extraction subagent (symlinked into `~/.claude/agents` by install; used by `/ask` and `kb-recall`).
- `librarian/procedure-file.md` — canonical filing procedure shared by the slash command and the headless librarian script.
- `scripts/kb` — the deterministic CLI (see below). `scripts/kb-mcp` — read-only MCP adapter over the CLI. `scripts/validate.py` — schema validator. `scripts/audit-topics.py` — topic normalization. `scripts/librarian` — headless maintenance (file / split / collapse / dedup / criticize / mine-recipes). `scripts/librarian-nightly` — the deterministic nightly job (launchd).
- `hooks/session-start.sh` — tiered ambient payload (`kb ambient`). `hooks/auto-recall.sh` — semantic per-prompt recall (`kb recall`, registered by default). `hooks/capture-candidate.sh` — SessionEnd unfiled-session queue. `hooks/allow-kb-query.sh` — PreToolUse permission hook (see above). `hooks/pre-commit` — schema validator gate (kb-data). `hooks/pre-commit-no-leaks` — leak guard on the engine repo itself, scanning every commit against the private `$KB_DATA_DIR/_banned-terms.txt`. `hooks/normalize-topics.sh` — retired from per-session use (nightly `kb sync` covers it). `hooks/session-end.sh` — legacy unconditional auto-file (off by default).

## The `kb` CLI

```sh
kb index            # build/refresh FTS5 + local embeddings (incremental; auto-runs before searches)
kb search <terms> [--mode hybrid|lexical|vector] [--type recipe] [--topic t] [--person p] [--json] [-n 10]
kb show <id|kb:/uri|path> [--path]
kb edges <id> [--json]      # typed edges, forward AND reverse ("what links here")
kb routes [--compact|--deep]   # route layer + BASELINE metrics
kb ambient [--cwd PATH]     # the tiered SessionStart payload (folder map + repo-relevant entries + deltas)
kb recall                   # prompt on stdin -> at most 3 relevant leaves, or silence (auto-recall core)
kb reindex-routes [--dry-run]  # regenerate entries[]/subroutes[]/last_indexed from leaves
kb sync             # reindex-routes + audit-topics --fix + index — run after any filing
kb doctor           # broken refs, stale recipes, drift-risk, route drift, model hygiene
kb problems scan|list|brief|resolve|drop   # the epistemic ledger
kb eval [--recall] [--save-baseline]       # retrieval metrics over the _eval.yaml gold set
kb serve --mcp      # read-only MCP server (stdio) — the KB for clients outside Claude Code
```

Search is **hybrid**: BM25 (FTS5, porter-stemmed, phrase-aware) ∪ local static
embeddings (model2vec `potion-retrieval-32M` — numpy inference, no torch, no server,
~ms per query), fused with reciprocal-rank fusion. Every doc gets a `head` vector
(title+topics+summary) plus body-chunk vectors; without the model everything degrades
silently to lexical. Quality is measured, not asserted: `kb eval` runs a gold set of
natural-phrasing queries (MRR@10 / recall@k per mode, stored baselines, exit-1 on
regression) — on the author's corpus hybrid lifts recall@5 from 0.81 to 0.88 over
lexical. The same harness's no-hit set calibrates auto-recall's thresholds
(`kb eval --recall`: zero false-fires required before the hook registers).

Route files stay half-curated: `purpose`, `related`, and the prose body are yours
(and the LLM's at filing time); `entries[]`, `subroutes[]`, and `last_indexed` are
derived data owned by `kb sync`. Hand-edited one-line entry summaries are preserved.

## Ambient context

`install.sh` registers a SessionStart hook (matcher `startup|clear`) that injects
`kb ambient --cwd <session-cwd>` as `<kb-ambient-index>`, tiered so cost is
O(folders), not O(entries):

- **Tier A (always, ~2-3k tokens):** folder map, recipe triggers, model statements.
- **Tier B (repo-relevant):** full one-line entry lists, but only for KB folders
  matching the repo the session opened in (basename + git-remote tokens; fails closed).
- **Tier C (deltas):** the problem ledger's brief (counts, aging, ready experiments),
  the nightly digest while fresh, and the unfiled-session queue.

Pause with `touch $KB_DATA_DIR/.no-ambient`.

`hooks/auto-recall.sh` (UserPromptSubmit, registered by default) scores every prompt
via `kb recall`: head-vector cosine ∪ corroborated BM25, thresholds calibrated on the
gold set's no-hit queries, session-scoped dedupe. Silence is the default; a hit
injects at most 3 WARM summaries. Kill switch: `touch $KB_DATA_DIR/.no-auto-recall`.

## MCP: the KB outside Claude Code

`kb serve --mcp` (or `scripts/kb-mcp` directly) exposes the KB read-only over MCP
stdio — point claude.ai desktop or any MCP client at it. The server is a ~100-line
adapter that shells out to the same CLI (`kb_search`, `kb_show`, `kb_edges`,
`kb_routes`, `kb_problems`), spawned per-client, no port, never writes. Its heavy
SDK dependency lives in its own PEP 723 block, so normal `kb` invocations never
carry it.

## Filing stays a human decision — but a 2-second one

Filing happens when you run `/file-this` (inline) or `/file-this --bg` (a background
librarian files the transcript while you keep working). There is **no unconditional
auto-file** — auto-filed noise erodes trust in the corpus. Instead, a deterministic
SessionEnd hook (`capture-candidate.sh`) queues sessions with real substance
(>8 user turns) into an **UNFILED SESSIONS** list in the next session's ambient
payload; saying "file #1" hands that transcript to the background librarian. One
human bit — "worth keeping?" — stays exactly where a human is cheapest. Entries
expire after 14 days; kill switch: `touch $KB_DATA_DIR/.no-capture-queue`.

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
- [x] Delegated extraction: `kb-researcher` subagent (Haiku) + `/ask` — transcript-depth answers without HOT-loading transcripts
- [x] Deduction layer: `type: model` (`kb:/models/`) + `/theorize` + prediction-check on filing + model hygiene in `kb doctor`
- [x] Day-2 Phase 4: hybrid semantic search (model2vec + RRF; trigger fired at 150k deep tokens) + `kb eval` harness
- [x] Scheduled maintenance: nightly librarian (validate, autosave, sync, doctor delta, ledger scan, digest) + weekly WIP-gated headless critic
- [x] Problem ledger (`kb:/problems/`, `kb problems`) + `/run-experiment` — the resolve loop
- [x] Ambient v2 (tiered, cwd-aware) + semantic auto-recall (registered) + capture queue + `/file-this --bg`
- [x] MCP server (`kb serve --mcp`) — the KB for clients outside Claude Code
- [ ] link-fix mode (when path-rewrite bugs surface)
- [ ] demo tape refresh (vhs) showing hybrid search + the resolve loop

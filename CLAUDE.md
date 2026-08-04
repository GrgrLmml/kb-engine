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

- `kb search <terms>` — hybrid ranked search: BM25 ∪ local vectors (model2vec), RRF-fused (self-refreshing index; `--mode lexical|vector|hybrid`, silent lexical fallback without the model). `--type recipe|model|problem|…`, `--topic`, `--person`, `--all-status`, `--json`. Quoted spans are phrase matches.
- `kb show <id>` / `kb show --path <id>` — resolve any id / `kb:/` URI / path.
- `kb edges <id>` — typed edges, forward and reverse.
- `kb routes [--compact|--deep]` — the route layer + BASELINE size metrics.
- `kb sync` — after writing any leaf: regenerates route `entries[]`/`subroutes[]`/`last_indexed`, normalizes topics, refreshes the index. Never hand-edit those route fields.
- `kb doctor` — broken refs, stale recipes, evidence drift (newer entries in an active recipe's topic area since it was last verified/edited → `drift-risk`), route drift.
- `kb problems scan|list|brief|resolve|drop` — the epistemic ledger (`kb:/problems/`, `type: problem`): doctor findings made durable with a lifecycle (`open → ready → resolved|dropped`). `scan` mints/reconciles stubs deterministically; `/criticize` writes each stub's pre-registered crucial experiment (`ready`); `/run-experiment` observes and resolves. `resolve` requires `--by <episode-id>` — no resolution without filed evidence.
- `kb eval [--recall] [--save-baseline]` — retrieval-quality metrics (MRR/recall) over the `_eval.yaml` gold set; `--recall` calibrates the auto-recall thresholds against the no-hit set.
- `kb ambient [--cwd PATH]` — the tiered SessionStart payload (folder map + cwd-relevant entry lists + problem/digest/capture deltas).
- `kb recall` (prompt on stdin) — semantic auto-recall: at most 3 relevant leaves or silence; session-deduped. Powers the UserPromptSubmit hook.
- `kb serve --mcp` — read-only MCP server (stdio) over the same CLI, for clients outside Claude Code (`scripts/kb-mcp`).

The tiered ambient payload is auto-injected into new sessions as `<kb-ambient-index>` (SessionStart hook): folder map always, full entry lists only for KB folders matching the session's repo, plus problem-ledger and nightly-digest deltas. A UserPromptSubmit hook (`auto-recall.sh` → `kb recall`) surfaces up to 3 relevant leaves per prompt, calibrated to stay silent on irrelevant ones. The `kb-recall` skill reaches into the KB proactively. A nightly launchd agent (`scripts/librarian-nightly`) validates, auto-commits kb-data, syncs, diffs doctor findings, reconciles the problem ledger, rotates logs, and writes a digest — plus one weekly headless `/criticize` pass, WIP-gated on unrun experiments.

## Commands

Run any of these in a Claude Code session once installed:

- `/find <query>` — ranked search; pulls best matches to WARM tier, follows curated edges.
- `/ask <question>` — answer a question from the KB via the cheap `kb-researcher` subagent (Haiku reads the transcripts, main context gets only the distilled cited answer). The `kb-recall` skill takes this same route automatically for plain questions.
- `/file-this [--bg] [hint]` — file the current conversation into the KB (`--bg`: hand it to a background librarian and keep working).
- `/jot <fact>` — capture a small durable fact in seconds (minimal leaf, no transcript).
- `/start <intent>` — bootstrap a session with relevant KB context.
- `/promote <id>` — load an entry's full transcript (HOT tier).
- `/extract-recipe [id|hint]` — distill a reusable procedure ("how we do X") into `kb:/recipes/`.
- `/mine-recipes [kb:/folder]` — mine the KB for recurring procedures, propose them as draft recipes, flag skill-graduation candidates.
- `/theorize [kb:/folder]` — the theory layer's growth pass: harvest open problems, conjecture explanatory models (falsifiable hard-to-vary claims, `kb:/models/`) through a criticism gate, chain model statements into derived conclusions, flag premise contradictions.
- `/criticize [model-id]` — the criticism pass: attack live models (hard-to-vary, consistency, counterexample sweep), conjecture rivals for lone hypotheses, write pre-registered crucial experiments into the problem ledger.
- `/run-experiment [problem-id]` — execute one `ready` experiment from the ledger using the session's real tools (Datadog/BigQuery/Slack MCP), map the result onto the pre-registered outcomes, and resolve: winner corroborated, loser refuted or narrowed. Closes the conjecture-and-criticism loop.
- `/dedup` · `/tidy` — librarian housekeeping (`/tidy` runs split + collapse + dedup + recipe-mining passes; the standalone split/collapse commands are retired).
- `/graduate-recipe <id>` — turn a proven recipe into a personal Claude Code skill (`~/.claude/skills/`), recipe stays as provenance.

## Layout

- `commands/` — slash commands (symlinked into `~/.claude/commands` by install).
- `skills/` — proactive skills (`kb-recall`), symlinked into `~/.claude/skills` by install.
- `agents/` — subagent definitions (`kb-researcher`: cheap read-only transcript extraction), symlinked into `~/.claude/agents` by install.
- `librarian/` — the canonical filing/split/collapse/dedup/extract-recipe/mine-recipes/theorize procedures.
- `scripts/` — `kb` (deterministic CLI: search/show/edges/routes/sync/doctor/problems/eval/ambient/recall/serve), `kb-mcp` (read-only MCP adapter over the CLI), `validate.py` (schema), `audit-topics.py` (topic normalization), `librarian` (headless: file/split/collapse/dedup/criticize/mine-recipes), `librarian-nightly` (deterministic nightly job, run by launchd).
- `hooks/` — `session-start.sh` (tiered ambient payload via `kb ambient`), `auto-recall.sh` (semantic per-prompt recall via `kb recall`, registered by default), `capture-candidate.sh` (SessionEnd: queues substantial unfiled sessions), `allow-kb-query.sh` (PreToolUse: auto-allows read-only kb queries), `pre-commit` (kb-data schema validator), `pre-commit-no-leaks` (ENGINE repo leak guard: blocks commits containing terms from the private `$KB_DATA_DIR/_banned-terms.txt` — this repo is public, KB content must never leak in), `normalize-topics.sh` (retired from per-session use — nightly `kb sync` covers it), `session-end.sh` (legacy unconditional auto-file, off by default).
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

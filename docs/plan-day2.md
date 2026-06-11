# Day-2 maturity plan — from PoC to a KB you actually live in

*Draft 2026-06-10. Status update same day: Phases 1–3 and the Phase-5 `kb doctor`
piece are SHIPPED (defaults chosen: global ambient injection with `.no-ambient`
kill switch; routes partially derived; auto-recall built but not registered; CLI
not MCP; jot = normal entry with minimal body). Phase 4 remains trigger-gated;
scheduled tidy and link-fix remain open.*

## Where we are

The PoC works: filing, routes, typed edges, recipes, validation, topic normalization.
Corpus today: **55 leaves, 24 routes, ~730 KB on disk, ~8.3k tokens route layer / ~47k
tokens deep** — tiny relative to a context window.

But day-to-day it feels clunky, and the clunk concentrates in one place: **every
operation is LLM-mediated, and every interaction is pull-based.**

### Friction diagnosis

1. **Search is slow and non-deterministic.** `/find` spawns an Explore subagent that
   traverses `_route.md`, prunes to top-3 branches, and greps. That's tens of seconds
   to minutes per lookup, and a "not found" can't be trusted. The KB itself already
   diagnosed this (`2026-06-04-retrieval-roadmap`): LLM-tree-traversal is the awkward
   middle — pays LLM tokens per query *and* prunes like an index without the determinism.
2. **`/load-kb` is the right bet but manual.** You have to remember to run it, every
   session, and it leans on a fragile zsh one-liner. 8k tokens is cheap enough to just
   *always be there*.
3. **The KB never volunteers anything.** Nothing surfaces unless you explicitly run a
   command. A KB that's actually cool is *ambient*: the session starts already knowing
   what exists, and Claude reaches into it unprompted when the conversation touches a
   person / project / past decision.
4. **No deterministic primitives.** Resolving an id (`/promote` prose-instructs a grep),
   concatenating routes, regenerating indexes — all done by prompting the LLM to run
   shell pipelines. These should be one boring CLI.
5. **Routes are derived data maintained by hand (well, by LLM-hand).** `entries[]`,
   `last_indexed`, topic bubbling — all mechanically derivable from the leaves, yet
   maintained by the LLM during filing. Result: drift, the 4 standing validation
   errors, and filing that takes minutes.
6. **Filing is heavyweight**, which is the worst place for friction — capture friction
   compounds: every conversation you don't file is a future retrieval miss.

### Design principles (carried over from the retrieval roadmap, made explicit)

- **Storage ≠ retrieval.** The curated tree + typed edges are great *organization*.
  They should not be the *retrieval algorithm*.
- **LLM judgment is the scarce resource; spend it on distilling and re-ranking, never
  on traversal or bookkeeping.** Everything mechanical goes into a script.
- **Push beats pull.** Hooks inject; skills trigger proactively; commands remain as
  explicit overrides.
- **No infra.** SQLite (stdlib) over Docker/Qdrant. The hybrid-search deferral and its
  trigger (~150–200k deep tokens) stand.

---

## Phase 1 — the `kb` CLI: deterministic core

One self-contained script (`scripts/kb`, PEP 723 / `uv run` like `validate.py`),
SQLite FTS5 index at `$KB_DATA_DIR/.index/kb.db` (gitignored, rebuilt incrementally
by mtime). FTS5 ships with Python — zero install, zero server, milliseconds per query.

| Subcommand | Does | Replaces |
|---|---|---|
| `kb index` | build/refresh FTS index (frontmatter fields weighted: title, topics, summary, when_to_use > body) | — |
| `kb search <query> [--topic X] [--person Y] [--type recipe] [--all-status] [-n 15]` | BM25-ranked hits: id, path, score, title, one-line summary | the Explore subagent's traversal+grep |
| `kb show <id-or-kb-uri>` | resolve and print an entry | `/promote`'s prose-grep |
| `kb edges <id>` | print resolved typed edges (related / supersedes / superseded_by / contradicts) | manual edge-following |
| `kb routes` | emit the concatenated route layer + the BASELINE metric line | `/load-kb`'s zsh one-liner |
| `kb reindex-routes` | **regenerate** `entries[]` + `last_indexed` + rolled-up topics in every `_route.md` from leaf frontmatter; keep hand-written `purpose`, `related`, prose | LLM route bookkeeping |

Then rewire the commands to *use* it:

- **`/find` v2 — no subagent.** Main agent runs 1–3 `kb search` variants (the LLM is
  good at generating query reformulations — that's judgment), gets ~15 candidates in
  under a second, re-ranks them, expands the top few via `kb edges` (the
  supersedes/contradicts logic stays — it's the highest-signal part of today's /find),
  presents top 5. Latency drops from ~a minute to a few seconds, and recall stops
  depending on which branch a subagent happened to descend.
- **`/promote`** → `kb show`. **`/load-kb`** → `kb routes`.
- **Index freshness**: `kb index` is cheap enough to run at the top of `/find`, plus
  from the existing SessionEnd hook alongside topic normalization.

This phase alone removes most of the day-to-day clunk.

## Phase 2 — ambient context: push, not pull

1. **SessionStart hook injects the index.** A hook emits a *compact* index (folder
   purposes + `id | title | one-liner` per active entry + recipe `when_to_use`
   triggers) as additionalContext — call it the route layer distilled to ~4–6k tokens
   via `kb routes --compact`. Every session starts already knowing what the KB
   contains; `/load-kb` becomes the explicit "give me the full version" override.
   Scope it (global vs. per-project allowlist) — open question below.
2. **A `kb-recall` skill that triggers proactively.** Today's commands are user-invoked.
   Add one skill whose description tells Claude *when to reach into the KB on its own*:
   "when Gregor mentions a person, project, decision, incident, or asks 'have we /
   how do we / what did we decide' — run `kb search` before answering." With the
   compact index already in context, Claude also knows *that* something exists and can
   pull it WARM/HOT itself. This is the "really cool" moment: the KB behaves like
   memory, not like a filing cabinet.
3. **(Experimental, off by default) auto-recall on prompt.** A UserPromptSubmit hook
   that FTS-queries each prompt and injects hits above a score threshold. True ambient
   memory, but noise-risky — ship behind a toggle, evaluate for a week, keep or kill.

## Phase 3 — frictionless capture

1. **Slim `/file-this`.** The LLM keeps only the judgment steps: distill, pick the
   folder, write the leaf. Everything after — route updates, bubbling, normalization,
   indexing — becomes one line: `kb reindex-routes && kb index && audit-topics.py --fix`.
   Filing goes from minutes to ~30 seconds, and a whole class of validator errors
   (leaf/route drift) becomes structurally impossible.
2. **`/jot <fact>` — capture without a transcript.** Half the value of a KB is small
   durable facts ("staging Qdrant lives in cluster X", "dana owns the vendorco
   relationship") that don't deserve a full filed conversation. A jot is a minimal
   leaf (frontmatter + 2–3 lines, no transcript body) filed in seconds.
3. **Fix the 4 standing kb-data validation errors** (res-3616 colon, week-23 status,
   week-19/21 `sources_dump`) so commits flow again — small, do it first.
4. **Optional: file in the background.** `/file-this --bg` hands the distillation to a
   background agent so the session isn't blocked while filing.

## Phase 4 — hybrid semantic search (unchanged, still trigger-gated)

The 2026-06-04 deferral stands: FTS5 + LLM re-rank + ambient index covers 55 (or 500)
entries. When `kb routes` reports the deep corpus approaching ~150–200k tokens, add an
embeddings table to the *same* SQLite file (`sqlite-vec`) and make `kb search` hybrid
(BM25 ∪ vector, reciprocal-rank fusion). Still no Docker, no Qdrant. The CLI from
Phase 1 is deliberately the chassis this bolts onto.

## Phase 5 — lifecycle polish (the librarian grows up)

- **Staleness pass** (the old slice 6): flag entries untouched for N months,
  recipes whose `last_verified` is old or whose referenced scripts/paths no longer
  exist (`kb doctor`).
- **Scheduled tidy**: run `/tidy` + `kb doctor` weekly via a scheduled agent / cron
  instead of remembering to.
- **link-fix mode** on top of `kb` id resolution (ids make moves cheap now).

---

## Sequencing & effort

| Phase | Effort | Payoff |
|---|---|---|
| 3.3 fix validation errors | minutes | unblocks commits |
| 1 `kb` CLI + rewired /find /promote /load-kb | ~1 session | kills most clunk |
| 2.1 + 2.2 ambient index + proactive skill | ~1 session | the "cool" unlock |
| 3.1 + 3.2 slim filing + /jot | ~1 session | capture stops hurting |
| 2.3 auto-recall experiment | small | maybe magic, maybe noise |
| 4, 5 | later | trigger-gated |

## Open questions for discussion

1. **Ambient scope** — inject the compact index in *every* Claude Code session
   (it's your personal memory, after all) or only in an allowlisted set of projects?
   Global is cooler; per-project is safer for token budgets and irrelevance.
2. **Routes fully derived?** Proposal keeps `purpose`/`related`/prose hand-curated and
   derives only `entries[]`/`last_indexed`/topics. Go further (routes 100% generated)
   or is the curation the point?
3. **UserPromptSubmit auto-recall** — try it, or is the proactive skill (Claude decides
   when to search) the better-taste version?
4. **CLI vs MCP server** — recommendation: plain CLI. Single-user, local, and Claude
   drives it through Bash fine. MCP adds a process and config for no capability gain.
   Revisit only if the KB should serve sessions outside Claude Code.
5. **`/jot`** — separate leaf shape (tiny, no transcript) or just a normal entry with
   an empty body? Leaning: normal entry, empty body, `topics: [jot]` not needed —
   keep one schema.

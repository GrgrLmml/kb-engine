# Filing procedure (canonical)

This is the single source of truth for how a conversation gets filed into Gregor's KB. Both `/file-this` (live in a Claude Code session) and the headless librarian script follow it.

**Division of labour:** you *judge* (what this conversation was, where it belongs, what was decided); `kb file` *writes* (id, timestamps, YAML quoting and key order, the transcript, folder bootstrap, schema validation, route bookkeeping, index refresh). Never hand-write a leaf file or a `_route.md`; never re-type the transcript.

**CLI:** `$KB_ENGINE_DIR/scripts/kb` · **KB root:** `$KB_DATA_DIR` · **Schema (reference only, you don't write it):** `$KB_ENGINE_DIR/docs/schema.md`

You will be told whether the conversation to file is:
- **the current session** (via `/file-this`) — it is already in your context; use `--session auto --cwd "$PWD"`, or
- **a transcript on disk** (headless) — read it with `$KB_ENGINE_DIR/scripts/kb transcript <path>` (condensed, faithful; never Read the raw JSONL), then use `--session <path>`.

An optional one-line placement hint may be given.

## Procedure — two tool calls in the common case

1. **Distill** (no tool call — think):
   - `title` ≤ 70 chars.
   - `summary`: two paragraphs, self-contained — someone reading only this must know what the entry is about and what came out of it. This is the WARM-tier payload and the main retrieval surface.
   - `topics`: 3–6 tags. Use canonical forms from `$KB_DATA_DIR/_topics.yaml` when you know them (`kb sync` normalizes aliases afterwards anyway). Don't merge a tag onto a polysemous term with a different meaning (e.g. `backend` → prefer `model-generation` / `routing`).
   - `decisions`: every explicit decision, one line each, self-contained (a reader should not need the transcript to understand them; name the thing decided and the reason).
   - `claims`: the **current-state facts** this conversation established, keyed so the engine can track them over time — anything that could be false tomorrow because the world changed: a setting, a threshold, a routing rule, which service does what, who owns what, which dashboard/monitor is live. Each: `{"subject": "<area>.<thing>.<attribute>", "value": "<the value, one line>", "since": "YYYY-MM-DD", "kind": "observed|inferred|reported", "scope": {"dim": "v"} (only for exceptions), "source": "<url>"}`. Reuse existing subjects: run `kb subjects --match "<words>"` once if unsure — a new key when an existing one means the same thing is the one mistake that hurts. History ("we decided X") stays in `decisions`; state ("X is now Y") goes in `claims`. Most short conversations have 0–3 claims; that is fine.
   - `open_questions`: what was left dangling.
   - `sources`: external URLs mentioned (Jira / Slack / PR permalinks / gs://). Nothing else.
   - `participants`: default `["gregor"]`.
   - `recipe_candidate`: `true` only if the conversation composed ≥3 distinct tools/data sources AND reached a repeatable outcome (a method you'd run again). One-off investigations, single decisions, 1:1 notes: `false`.
   - `folder`: the `kb:/` folder whose purpose best matches — from the ambient `<kb-ambient-index>` folder map if in context, else run `kb routes --compact` once. Prefer the hint if given, unless it clearly misfiles. If no folder fits and the topic warrants its own, name a new folder one level below an existing one and give `folder_purpose` (one good sentence — hand-curated forever).

2. **Write** — one call:
   ```sh
   "$KB_ENGINE_DIR/scripts/kb" file --session auto --cwd "$PWD" --meta - <<'JSON'
   {"title": "...", "folder": "kb:/work/...", "topics": ["..."], "participants": ["gregor"],
    "summary": "...\n\n...", "decisions": ["..."], "open_questions": ["..."],
    "sources": ["https://..."], "recipe_candidate": false,
    "claims": [{"subject": "service.decoder.sampling-temperature", "value": "0 (greedy), settings default", "since": "2026-09-15", "kind": "observed", "source": "https://..."}]}
   JSON
   ```
   (headless: `--session <jsonl path>` instead of `auto`.) It prints either `FILED <path>` plus a report, or `REFUSED` with schema errors — then nothing was written; fix the payload and re-run. The report says, per claim, whether it **confirms** or **SUPERSEDES** an earlier claim on the same key (that is the engine noticing the world changed — no action needed, but if a supersession surprises you, say so in your report) and flags **new subjects** — if `kb subjects --match` shows an existing key that means the same thing, edit the leaf's `claims[].subject` to it and `kb sync`.

3. **Check the living layer** — only what the report lists. `kb file` ends with `same-topic living layer:` — the models and recipes sharing a topic with the new entry (usually none). For each listed id, `kb show <id>`, read `statement`/`predictions` (model) or `when_to_use`/`steps` (recipe), and compare against what you just filed:
   - **Model contradicted** by this episode → append the new id to `refuted_by`, bump `updated`, flag it in your report. Do NOT flip the status — Gregor decides refute-vs-boundary-condition.
   - **Model prediction matched** → append the new id to `evidence_for` (never for a model whose `derived_from` already holds it — grounding isn't corroboration), bump `updated`; first later match flips `hypothesis → corroborated` (survived a test; never "validated").
   - **Recipe claim outdated** (a step, a "currently X" caveat) → edit the recipe text in place, cite the new id, append it to `derived_from`, bump `updated`. **Recipe executed successfully** → bump `last_verified`.
   - Neither → nothing. If you edited anything: `"$KB_ENGINE_DIR/scripts/kb" sync --quiet`.

4. **Report back**, short: the `FILED` path and id, topics, one-line summary, any model/recipe flags from step 3 (`REFUTATION FLAGGED — review <model-id>` / `<recipe-id>: step updated — <one line>`).

## Constraints

- Do not invent participants, decisions or sources. Unknown → leave empty.
- `decisions` are facts about the world/our systems as decided or established in the conversation — not a to-do list.
- Do not run `git commit`. Filing produces working-tree changes only; Gregor reviews and commits manually.

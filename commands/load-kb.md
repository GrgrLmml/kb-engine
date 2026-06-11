---
description: Load the entire KB routing layer into the main context (high-recall baseline — the alternative to /find's ranked search)
argument-hint: "[--deep] [optional query to answer from the loaded corpus]"
---

You are loading Gregor's whole knowledge base **index** into *this* (main) context, then optionally answering: **$ARGUMENTS**

**KB root:** `$KB_DATA_DIR`

## Why this exists (read before running)

`/find` runs a ranked BM25 search and returns the top hits. That is fast but still a ranked cut — a relevant entry can fall below the cutoff. `/load-kb` is the opposite bet: pull the **complete** summary corpus into the main context in one shot and let the model reason over *all* of it. Prompt caching makes re-reading the same corpus across turns nearly free. This is the **recall baseline** — the number every fancier retriever must beat — and each run **measures** the corpus size so we can see when it stops fitting comfortably.

Do NOT delegate this to a subagent. The whole point is to bring the corpus HOT into the main context so it stays cached and reusable for the rest of the session.

## Procedure

1. **Decide the level** from $ARGUMENTS and run the matching command in a single Bash call so the corpus lands in one tool result (cached as a unit):

   - default (no `--deep`) — the **route layer** only (folder purposes, subroute summaries, one-line entry summaries):
     ```sh
     $KB_ENGINE_DIR/scripts/kb routes
     ```
   - `--deep` — additionally every **leaf's frontmatter** (two-paragraph summaries, topics, typed edges):
     ```sh
     $KB_ENGINE_DIR/scripts/kb routes --deep
     ```

   Both print a `BASELINE:` metrics line at the end (routes / entries / chars / est_tokens).

2. **Answer (only if a query was given).** With the full index in context, surface the entries relevant to the query — including ones a keyword search would miss. For each, give `id`, file path, and why it is relevant. Then expand along the typed edges you can now see: flag any `superseded_by` (prefer the newest), any `contradicts`, and list `related` neighbors worth pulling. Offer to load the full transcript (HOT) of the top hits — do not load transcripts unprompted.

   If no query was given, give a one-screen map of the KB (top-level folders and what each holds) and stop.

3. **Always repeat the BASELINE line** verbatim at the end, e.g. `BASELINE: level=route routes=NN entries=NN est_tokens=NN`. This is the measurement we are tracking. If `est_tokens` is climbing toward a large fraction of the context window, say so plainly — that is the signal to revisit hybrid search (see the KB retrieval roadmap note in `kb:/projects/kb/`).

## Constraints
- Default to active entries; mention if you are leaning on `superseded`/`archived` for a history question.
- This command only reads. It never modifies the KB.

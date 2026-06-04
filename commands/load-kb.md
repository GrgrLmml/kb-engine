---
description: Load the entire KB routing layer into the main context (high-recall baseline — the alternative to /find's traversal)
argument-hint: "[--deep] [optional query to answer from the loaded corpus]"
---

You are loading Gregor's whole knowledge base **index** into *this* (main) context, then optionally answering: **$ARGUMENTS**

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md`

## Why this exists (read before running)

`/find` spawns a subagent that *traverses* the `_route.md` tree, prunes to the top few branches, and greps. That is cheap but lossy — a relevant entry can be pruned or missed because a one-line summary did not anticipate the query.

`/load-kb` is the opposite bet: pull the **complete** summary corpus into the main context in one shot and let the model reason over *all* of it. Prompt caching makes re-reading the same corpus across turns nearly free. This is the **recall baseline** — the number every fancier retriever (hybrid search, graph) must beat. So it must also **measure** the corpus size each run, so we can see when it stops fitting comfortably.

Do NOT delegate this to a subagent. The whole point is to bring the corpus HOT into the main context so it stays cached and reusable for the rest of the session.

## Procedure

1. **Decide the level** from $ARGUMENTS:
   - default (no `--deep`): the **route layer** only — every `_route.md` (folder purposes, subroute summaries, and the one-line summary of every entry). Complete coverage of *what exists*, minimal tokens.
   - `--deep`: additionally load every **leaf's frontmatter** (the two-paragraph `summary`, `topics`, and the typed edges `related`/`supersedes`/`contradicts`). Richer, larger. Use when the query needs detail the one-liners do not carry.

2. **Load + measure.** Run the matching block in a single Bash call so the corpus lands in one tool result (cached as a unit):

   Route layer (default). Written to be zsh-safe (this machine's shell is zsh, which does NOT word-split unquoted vars — so pipe `find` into `while read`, never `for f in $var`):
   ```bash
   cd $KB_DATA_DIR
   find . -name _route.md | sort | while IFS= read -r f; do echo "===== $f ====="; cat "$f"; echo; done
   echo "===== BASELINE METRICS ====="
   nroutes=$(find . -name _route.md | wc -l | tr -d ' ')
   nentries=$(grep -rh '^\s*- id:' --include=_route.md . | wc -l | tr -d ' ')
   chars=$(find . -name _route.md -exec cat {} + | wc -c | tr -d ' ')
   echo "level=route routes=$nroutes entries=$nentries chars=$chars est_tokens=$((chars/4))"
   ```

   Add `--deep` (run this in addition):
   ```bash
   cd $KB_DATA_DIR
   fm() { awk '/^---$/{c++; print; if(c==2)exit; next} c==1{print}' "$1"; }
   find . -name '*.md' ! -name _route.md -not -path '*/.*' | sort | while IFS= read -r f; do echo "===== $f ====="; awk '/^---$/{c++; print; if(c==2)exit; next} c==1{print}' "$f"; echo; done
   chars=$(find . -name '*.md' ! -name _route.md -not -path '*/.*' -print0 | xargs -0 -I{} awk '/^---$/{c++; print; if(c==2)exit; next} c==1{print}' {} | wc -c | tr -d ' ')
   nleaves=$(find . -name '*.md' ! -name _route.md -not -path '*/.*' | wc -l | tr -d ' ')
   echo "===== DEEP METRICS ====="; echo "level=deep leaves=$nleaves frontmatter_chars=$chars est_tokens=$((chars/4))"
   ```

3. **Answer (only if a query was given).** With the full index in context, surface the entries relevant to the query — including ones a keyword grep would miss. For each, give `id`, file path, and why it is relevant. Then expand along the typed edges you can now see: flag any `superseded_by` (prefer the newest), any `contradicts`, and list `related` neighbors worth pulling. Offer to load the full transcript (HOT) of the top hits — do not load transcripts unprompted.

   If no query was given, give a one-screen map of the KB (top-level folders and what each holds) and stop.

4. **Always print the baseline line** verbatim at the end, e.g. `BASELINE: level=route entries=NN est_tokens=NN`. This is the measurement we are tracking. If `est_tokens` is climbing toward a large fraction of the context window, say so plainly — that is the signal to revisit hybrid search (see the KB retrieval roadmap note in `kb:/projects/kb/`).

## Constraints
- Default to active entries; mention if you are leaning on `superseded`/`archived` for a history question.
- This command only reads. It never modifies the KB.

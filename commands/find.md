---
description: Search Gregor's KB and pull the best matching entries into context (WARM tier)
argument-hint: <free-form query — what you're looking for>
---

You are searching Gregor's knowledge base for entries relevant to: **$ARGUMENTS**

**KB root:** `$KB_DATA_DIR`
**Search CLI:** `$KB_ENGINE_DIR/scripts/kb` (deterministic BM25 index — the index refreshes itself on every search, no need to rebuild)

## Procedure

Do this **inline** — no subagent. The CLI does the mechanical work in milliseconds; you spend judgment only on query formulation, re-ranking, and edge expansion.

1. **Search.** Run 1–3 searches in one Bash call. Start with the user's words; add a reformulation if the query is paraphrastic (the index is lexical — translate concepts into the vocabulary the KB likely uses: tool names, ticket ids, people, canonical topics):

   ```sh
   $KB_ENGINE_DIR/scripts/kb search <query terms> -n 15
   ```

   Useful flags: `--type recipe` (procedural "how do we…" queries — weight recipes higher), `--topic <tag>` / `--person <name>` (repeatable filters), `--all-status` (only when the query asks for history; default excludes superseded/archived).

2. **Re-rank with judgment.** The BM25 score is a candidate generator, not the verdict. Read the returned titles/topics/summaries and pick the entries that actually answer the query. Recency breaks ties. Recipes answer "how do we do X" rather than "what happened" — label them `[recipe]`, and `(draft)` if status is draft.

3. **Expand along the curated typed edges** for the top 2–3 candidates — these hand-maintained links carry meaning a keyword match cannot:

   ```sh
   $KB_ENGINE_DIR/scripts/kb edges <id>
   ```

   - **`superseded_by`** → the candidate is stale. Pull the superseder, prefer it, and mark the old one. **`supersedes`** → note what it replaced (offer only for historical queries).
   - **`contradicts`** → surface the conflicting entry alongside and flag the disagreement. Never silently return one side.
   - **`related`** (forward *and* reverse — the CLI prints "what links here") → include any neighbor that independently bears on the query, even with zero keyword overlap. That's the point of the edges.

4. **Return up to 5 hits**, in this format per hit:
   ```
   [<score>] <id>            (found via: search | edge:related-from <id> | supersedes <id>)
     file: <absolute path on disk>
     title: <title>
     created: <date>
     topics: <topics>
     edges: <superseded_by / contradicts / related ids worth knowing, or "none">
     summary: <the entry's summary field, verbatim>
   ```
   If any hit is superseded or contradicted, say so in one line above the list. End with: "Read the file directly to load the full transcript (HOT tier)."

   If nothing crosses a relevance threshold, say so plainly — do not pad with weak matches. (`kb search` printing "no hits" is trustworthy: the index covers every entry, unlike the old traversal.)

5. **On follow-up** "load N" / "promote N": Read that file to bring it HOT into the main context. Do not load transcripts unprompted — the summaries are the WARM payload, that's the point.

## Constraints

- Read-only: never modify the KB from this command.
- The summaries `kb search` prints are truncated one-liners. For the verbatim `summary` field in your output, read it from the hit file's frontmatter (head -40 of the file is enough) — do not paste the truncated line.

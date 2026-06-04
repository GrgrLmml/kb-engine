---
description: Search Gregor's KB and pull the best matching entries into context (WARM tier)
argument-hint: <free-form query — what you're looking for>
---

You are searching Gregor's knowledge base for entries relevant to: **$ARGUMENTS**

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md`

## Procedure

Spawn an Explore subagent to do the actual search, so the main context stays clean. Brief it as follows:

> Search the knowledge base at `$KB_DATA_DIR` for entries relevant to: `$ARGUMENTS`
>
> Strategy — combine traversal and grep:
>
> 1. **Traverse `_route.md` files** starting from `$KB_DATA_DIR/_route.md`. At each route, read frontmatter (`purpose`, `topics`, `subroutes[].summary`, `entries[].summary`). Score each subroute and entry by relevance to the query. Descend into the top-scoring subroutes (up to 3). Also follow `related:` cross-links if they look promising — but never visit the same `_route.md` twice (the graph is cyclic).
>
> 2. **Grep within candidate folders.** Once you've narrowed to a handful of folders, grep their leaf entries for keywords from the query. Match against `title`, `topics`, `participants`, and `summary` fields, plus the body.
>
> 3. **Score and rank.** For each candidate entry, weigh:
>    - Topic / tag overlap with the query (tags are normalized against `kb-data/_topics.yaml`, so a query term may have a canonical synonym — match on the canonical)
>    - Title and summary similarity
>    - Recency (newer wins ties)
>    - Status (`active` only by default — skip `superseded` and `archived` unless the query asks for history)
>
> 4. **Expand along the curated typed edges.** This is the highest-signal step — these hand-maintained links carry meaning a keyword match cannot. For each top candidate, read its frontmatter edges and act on them:
>    - **`superseded_by`** → the candidate is stale. Pull the superseder, prefer it, and mark the old one. **`supersedes`** → note what this entry replaced (offer it only if the query is historical).
>    - **`contradicts`** → surface the conflicting entry alongside, and flag that they disagree. Never silently return one side of a contradiction.
>    - **`related`** → pull these 1 hop out; include any that independently bear on the query (they often won't share keywords with it — that's the point).
>    - **`participants`** → for "who" / person-scoped queries, treat as a match signal.
>    A neighbor reached via an edge is a valid hit even if it never matched the query's keywords or topics. Track visited ids so an edge cycle doesn't loop.
>
> 5. **Return up to 5 hits**, in this format per hit:
>    ```
>    [<score>] <id>            (found via: traversal | grep | edge:related-from <id> | supersedes <id>)
>      file: <absolute path on disk>
>      title: <title>
>      created: <date>
>      topics: <topics>
>      edges: <superseded_by / contradicts / related ids worth knowing, or "none">
>      summary: <the entry's summary field, verbatim>
>    ```
>    If any hit is superseded or contradicted, say so in one line above the list. End with: "Read the file directly to load the full transcript (HOT tier)."
>
> If no hits cross a relevance threshold, say so plainly — do not pad with weak matches.

After the subagent returns, present the hits to the user as-is. Do not load the full transcripts unless the user asks — the summaries are the WARM payload, that's the point.

If the user follows up with "load N" or "promote N" referring to a specific hit, then read that file with the Read tool to bring it HOT into the main context.

## Constraints

- Default to active entries only. Mention if you skipped superseded/archived hits.
- Treat the graph as cyclic — track visited routes to avoid loops.
- Keep the subagent focused on retrieval. It should not modify the KB.

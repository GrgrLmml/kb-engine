---
description: Bootstrap a session with relevant context from Gregor's KB based on what he's about to do
argument-hint: <free-form description of what you're starting — e.g. "prepare 1:1 with Alex" or "review open PRs">
---

You are bootstrapping a fresh Claude Code session. Gregor just said what he intends to do; pull the relevant prior context from his KB before he goes deeper.

**KB root:** `$KB_DATA_DIR`
**Schema:** `$KB_ENGINE_DIR/docs/schema.md`

**User's stated intent:** $ARGUMENTS

If $ARGUMENTS is empty, output exactly: "No intent given. Type `/start <what you're working on>` so I can pull relevant prior context." Then stop.

## Procedure

Spawn an Explore subagent to do the traversal so the main session's context stays clean. Brief it like this:

> Find KB entries and routes relevant to: **$ARGUMENTS**
>
> KB root: `$KB_DATA_DIR`
>
> Strategy — be thorough; this is bootstrapping a session, not a quick lookup:
>
> 1. **Extract anchors from the intent.** Pull out names of people, projects, repos, tickets, recurring patterns ("1:1", "sprint planning", "PR review"). These are your search keys.
>
> 2. **Traverse `_route.md` from root.** Start at `$KB_DATA_DIR/_route.md`. Read its frontmatter (`purpose`, `topics`, `subroutes[].summary`, `entries[].summary`). Score each subroute by overlap with the anchors. Descend into the top 2-3 subroutes. Recurse. Treat the graph as cyclic — track visited routes to avoid loops.
>
> 3. **Within candidate folders, grep leaf entries** for the anchors. Match against `title`, `topics`, `participants`, and `summary` frontmatter fields, plus the body. Newer entries win ties (look at `created`).
>
> 4. **Skip `superseded` and `archived` entries** unless the intent explicitly asks for history.
>
> 5. **Read the full WARM payload** (the `summary` field) for the top 3-5 entries you find. Also read `_route.md` files for the 1-2 most relevant folders.
>
> 6. **Return a structured brief** in this exact shape (markdown):
>
>    ```
>    ## Intent
>    <one-line restatement of what Gregor's doing, based on the matches>
>
>    ## Relevant entries
>    - **<title>** (<id>, <date>) — <verbatim summary, possibly truncated to ~3 lines>
>    - **<title>** (<id>, <date>) — <summary>
>    [up to 5]
>
>    ## Relevant folders
>    - **<title>** (`<kb:/...>`) — <purpose, plus a sentence on what's in there>
>    [up to 2]
>
>    ## Decisions worth remembering
>    - <decision text>  *(from <id>)*
>    - <decision>  *(from <id>)*
>    [bullet up to 5; pull from `decisions:` of the matched entries; group similar ones]
>
>    ## Open questions
>    - <question>  *(from <id>)*
>    [bullet from `open_questions:` of matched entries]
>
>    ## Files to read for full context (HOT)
>    - <full filesystem path>
>    [list the 1-3 paths Gregor would want to Read directly if he wants the transcripts]
>    ```
>
>    If a section has no content, emit `(none)` rather than skipping the heading.
>
>    If no matches cross a relevance threshold, emit:
>    ```
>    ## Intent
>    <restatement>
>
>    No matching prior context in the KB. Starting fresh.
>    ```
>
> Be honest about weak matches — say "weak match" in the entry summary rather than fabricating relevance.

After the subagent returns, present its output to Gregor verbatim. Add one line at the end:

> Want me to load any of these full? Just say "load <id>" or paste the file path.

## Constraints

- Do not load full transcripts in the main session — that's HOT and Gregor will ask for it explicitly. The subagent reads `summary` fields only.
- Do not modify the KB. /start is read-only.
- Treat the cyclic graph correctly — track visited routes.
- The brief should be skimmable in 10 seconds. Tighter is better than longer.

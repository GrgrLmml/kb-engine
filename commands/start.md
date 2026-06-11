---
description: Bootstrap a session with relevant context from Gregor's KB based on what he's about to do
argument-hint: <free-form description of what you're starting — e.g. "prepare 1:1 with Alex" or "review open PRs">
---

You are bootstrapping a fresh Claude Code session. Gregor just said what he intends to do; pull the relevant prior context from his KB before he goes deeper.

**KB root:** `$KB_DATA_DIR`
**Search CLI:** `$KB_ENGINE_DIR/scripts/kb`

**User's stated intent:** $ARGUMENTS

If $ARGUMENTS is empty, output exactly: "No intent given. Type `/start <what you're working on>` so I can pull relevant prior context." Then stop.

## Procedure

Do this inline — the CLI is fast enough that no subagent is needed.

1. **Extract anchors from the intent**: people, projects, repos, tickets, recurring patterns ("1:1", "sprint planning", "PR review").

2. **Search** (one Bash call, several searches):
   ```sh
   $KB_ENGINE_DIR/scripts/kb search <anchor terms> -n 10
   $KB_ENGINE_DIR/scripts/kb search --type recipe <intent terms> -n 5
   ```
   The recipe search is high-value: if Gregor is about to *do* something he's done before, the matching recipe is the most useful thing to hand him. Judge recipe relevance by `when_to_use` (the trigger describes the *situation*) — read it from the recipe file if the one-liner isn't enough.

3. **Read the WARM payload** — the frontmatter (`summary`, `decisions`, `open_questions`) of the top 3–5 entries and the `when_to_use` + `steps` of any matched recipe (`head -60` of each file in one Bash call). Skip superseded/archived (the CLI already does by default).

4. **Return a structured brief** in this exact shape (markdown):

   ```
   ## Intent
   <one-line restatement of what Gregor's doing, based on the matches>

   ## Recipes for this
   - **<recipe title>** (`<kb:/recipes/...>`) — <when_to_use, one line>. Steps: <the steps outline, one line>.
   [up to 3; mark "(draft, unverified)" where status is draft. This section comes first because a matching recipe is the most actionable thing.]

   ## Relevant entries
   - **<title>** (<id>, <date>) — <verbatim summary, possibly truncated to ~3 lines>
   [up to 5]

   ## Decisions worth remembering
   - <decision text>  *(from <id>)*
   [up to 5; pull from `decisions:` of the matched entries; group similar ones]

   ## Open questions
   - <question>  *(from <id>)*
   [from `open_questions:` of matched entries]

   ## Files to read for full context (HOT)
   - <full filesystem path>
   [the 1–3 paths Gregor would want to Read directly for the transcripts]
   ```

   If a section has no content, emit `(none)` rather than skipping the heading.

   If no matches cross a relevance threshold:
   ```
   ## Intent
   <restatement>

   No matching prior context in the KB. Starting fresh.
   ```

   Be honest about weak matches — say "weak match" rather than fabricating relevance.

Add one line at the end:

> Want me to load any of these full? Just say "load <id>" or paste the file path.

## Constraints

- Do not load full transcripts — that's HOT and Gregor will ask explicitly. Frontmatter only.
- Do not modify the KB. /start is read-only.
- The brief should be skimmable in 10 seconds. Tighter is better than longer.

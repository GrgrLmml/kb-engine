---
name: kb-recall
description: >-
  Proactively search Gregor's personal knowledge base before answering from
  scratch. TRIGGER whenever Gregor mentions a person, project, repo, ticket,
  incident, or recurring task that might have prior context; asks "have we /
  did we / what did we decide / how do we do X"; or starts work that smells
  like something done before (briefings, reports, runbooks, 1:1 prep, recovery
  procedures). Also trigger when the ambient <kb-ambient-index> shows a
  matching entry. DO NOT trigger for pure code questions about the currently
  open repo, or when the KB was already searched for the same thing this
  session.
---

# kb-recall — reach into the KB before answering cold

Gregor keeps a personal, LLM-managed knowledge base of filed conversations
(episodic entries), reusable procedures (recipes), and typed links between
them. A compact index of it may already be in context (`<kb-ambient-index>`).
This skill is how you pull the actual content.

**Paths:** the KB content root is `$KB_DATA_DIR`; the CLI is
`$KB_ENGINE_DIR/scripts/kb` (both env vars are set in every session).

## Procedure

1. **Search** (milliseconds, index self-refreshes):
   ```sh
   $KB_ENGINE_DIR/scripts/kb search <terms> -n 10
   ```
   - Procedural question ("how do we…") → add `--type recipe`.
   - Person-scoped → try `--person <name>` and the name as a plain term.
   - Historical ("what did we originally…") → add `--all-status`.
   - The index is lexical: reformulate paraphrases into KB vocabulary
     (tool names, ticket ids, canonical topics) and run 2–3 variants in one
     Bash call if the first is weak.

2. **Check edges of the best hit** — supersession and contradiction matter:
   ```sh
   $KB_ENGINE_DIR/scripts/kb edges <id>
   ```
   Prefer the superseder; never silently present one side of a `contradicts`
   pair.

3. **Read the WARM payload** (frontmatter summary) of the top 1–3 hits, e.g.
   `head -60` of each file.

4. **Route by depth.** Two cases:
   - **Summaries suffice** (who/when/what-was-decided at headline level) →
     answer inline from the WARM payload.
   - **The answer lives in transcript bodies** — exact commands, numbers,
     step-by-step "how did we do X last time", or synthesis across several
     entries ("overview of the last 3 incidents") → do NOT read the
     transcripts here. Delegate to the **`kb-researcher` subagent** (Agent
     tool, `subagent_type: "kb-researcher"`): pass the question verbatim plus
     the candidate ids from step 1. It reads the full transcripts in its own
     context (cheap model) and returns only the distilled, cited answer —
     relay that, citations intact.

   Reading a full transcript in the main context is reserved for when Gregor
   explicitly asks to go deep (`/promote`), or the delegated answer proved
   insufficient AND the entry is clearly on-point.

   **Theory layer:** `kb:/models/` holds `type: model` entries — explicit
   falsifiable claims with statements and predictions (their statements also
   appear in the ambient index). When a question asks "why" or "what would
   happen if", check whether model statements chain into an answer no episode
   records. Conclusions derived that way are always labeled
   `derived [model-id + model-id]` and inherit the weakest premise's status —
   never present a derivation as an observed fact.

5. **Use it, cite it.** Weave what you found into your answer and name the
   entry id(s) so Gregor knows where it came from. If nothing relevant turned
   up, just proceed — don't narrate the failed search beyond one short clause.

## Constraints

- Read-only. Filing happens via /file-this, never from this skill.
- Don't re-search the same query repeatedly in one session; the corpus only
  changes when something is filed.
- Keep it cheap: summaries first, then the kb-researcher subagent for
  transcript-depth questions; whole transcripts in the main context only on
  explicit demand.

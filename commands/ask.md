---
description: Ask the KB a question — a cheap subagent reads the transcripts and returns only the distilled answer
argument-hint: <question — e.g. "how did we trigger the recovery update last time?">
---

Answer a question from Gregor's KB **without loading transcripts into this context**. A cheap `kb-researcher` subagent (Haiku) does the reading in its own context and returns only the extracted answer with citations. This is the token-efficient middle path between `/find` (WARM summaries only) and `/promote` (whole transcript HOT).

**Question:** $ARGUMENTS

If $ARGUMENTS is empty, output: "Usage: `/ask <question>` — e.g. `/ask how did we trigger the recovery update last time?`" Then stop.

## Procedure

1. **Seed candidates (optional, cheap).** If the ambient `<kb-ambient-index>` or a search you already ran this session points at obvious entries, note their ids. Optionally run one quick `$KB_ENGINE_DIR/scripts/kb search <terms> -n 5` to seed — but do NOT read any transcripts yourself.

2. **Delegate.** Spawn the `kb-researcher` agent (Agent tool, `subagent_type: "kb-researcher"`) with a prompt of this shape:

   > Question: <the question, verbatim>
   > Candidate entries (from a quick search — verify, don't trust blindly): <ids, or "none — search yourself">
   > Return the distilled answer with verbatim quotes for commands/numbers and `Sources:` ids.

3. **Relay.** Present the subagent's answer to Gregor — keep its citations (entry ids) intact so he knows where it came from. Do not re-verify by reading the transcripts yourself; that would defeat the purpose. If the answer looks thin or the subagent reported a miss, say so plainly and offer the follow-ups:

   > Deeper: `/promote <id>` loads the full transcript here.

## Constraints

- Read-only end to end; the subagent is read-only too.
- Never read a full transcript in the main context from this command — that is `/promote`'s job, on Gregor's explicit request.
- One subagent per question; don't fan out unless the question itself is multi-part.

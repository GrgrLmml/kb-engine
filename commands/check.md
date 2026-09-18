---
description: Check a text (a bot's answer, a tool result, your draft reply) against the KB's current claims — "things are not as they appear"
argument-hint: [text to check — or leave empty to check the last tool result / your last answer]
---

You are checking a piece of text against Gregor's knowledge base: **$ARGUMENTS**

If `$ARGUMENTS` is empty, the text to check is the most recent substantial thing in context that makes factual assertions about our systems: the last external tool result (a code-search or knowledge bot, chat, issue tracker, web) or, failing that, your own last answer.

## Procedure — one tool call, then judgment

1. Run the check (text on stdin):
   ```sh
   "$KB_ENGINE_DIR/scripts/kb" check <<'TXT'
   <the text>
   TXT
   ```
   Exit 1 / no output = the KB holds no current claim on anything the text touches → say so in one line and stop.

2. For every subject printed, compare the KB's current claim(s) — value, scope, `since`, `kind`, source — with what the text asserts:
   - **Text contradicts the KB** → report it: *"text says X; KB says Y since D (source S, episode E)"*. Mind the scope: an exception (`[src_lang=lo|my]`) is not a contradiction of the default.
   - **Text is right and the KB is stale** (the text is newer, first-hand, or cites a change) → say so, and offer to file the correction as a claim (`/jot`) — the KB learns from being wrong.
   - **Agree** → one word.

3. Report: contradictions first, each with `since` and source so Gregor can paste it as a correction. Then stale-KB items. Nothing else.

Do not soften a contradiction into "may differ" when the KB claim is `observed`, dated, and sourced; do not overclaim when it is `reported` or `inferred` — say which kind it is.

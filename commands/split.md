---
description: Split a leaf KB folder into topic-coherent subfolders
argument-hint: <kb:/folder/to/split>
---

You are splitting a too-diverse KB folder into topic-coherent subfolders.

**Target folder:** $ARGUMENTS

If $ARGUMENTS is empty or doesn't start with `kb:/`, output: "Usage: `/split kb:/folder`. The folder must already exist and have ≥3 leaf entries directly in it." Then stop.

## Procedure

Spawn an Agent subagent (general-purpose) so the heavy file reading + writing happens in isolated context. Brief it like this:

> Read `$KB_ENGINE_DIR/librarian/procedure-split.md` and follow it for target folder `$ARGUMENTS`.
>
> You have full file access (Read, Write, Edit, Bash). Use `git mv` for moves so history is preserved.
>
> When you're done, run `$KB_ENGINE_DIR/scripts/validate.py` and confirm clean. Then output the final DONE summary the procedure prescribes.
>
> If preconditions fail, output `SKIPPED: <reason>` and stop. If clustering is low-quality, output `ABORTED: <reason>` and don't write anything.

After the subagent returns, present its output to Gregor verbatim. Add one trailing line:

> Review with `git -C $KB_DATA_DIR status` and commit when ready. Revert with `git -C $KB_DATA_DIR restore .` if you don't like the result.

## Constraints

- Don't load the full transcripts of the entries — only the frontmatter is needed for clustering. The subagent already knows this from the procedure file.
- Don't run `git commit`. Filing produces working-tree changes only.
- If the subagent reports validator errors after applying, surface them — don't try to "fix" them in the main session, that's how state gets confused.

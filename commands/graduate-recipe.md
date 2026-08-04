---
description: Graduate a stable KB recipe into a real Claude Code skill
argument-hint: <recipe-id>
---

Graduate the KB recipe **$ARGUMENTS** into a personal Claude Code skill. A recipe
earns graduation when it is stable (verified more than once, no open gotchas) and
mechanical enough that a skill can drive it without the KB's judgment steps.

1. **Load.** `$KB_ENGINE_DIR/scripts/kb show $ARGUMENTS` — it must be `type: recipe`.
   If its `skill:` field already names a skill, say so and stop (already graduated);
   offer to sync the skill with the recipe's latest steps instead.

2. **Check fitness.** `status: active` and `last_verified` set? If it's a draft or
   unverified, say what's missing and stop — graduation is for proven procedures.

3. **Scaffold the skill** at `~/.claude/skills/<recipe-id>/SKILL.md` (personal skills
   dir — NEVER into the kb-engine repo: the engine is public, recipe content is
   private). Frontmatter: `name` = recipe id, `description` = the recipe's
   `when_to_use` (this is the trigger — keep it sharp). Body: the recipe's body,
   restructured as skill instructions; keep exact commands, gotchas, and
   verification steps; drop KB-internal bookkeeping.

4. **Point the recipe at the skill.** Set `skill: <recipe-id>` in the recipe's
   frontmatter, bump `updated:`. The recipe stays in the KB as provenance and keeps
   receiving `derived_from`/`last_verified` updates from filings — on the next
   verified run, offer to sync the skill.

5. `$KB_ENGINE_DIR/scripts/kb sync` and `$KB_ENGINE_DIR/scripts/validate.py`.

6. Report: skill path, the trigger description, and a one-line reminder that
   `kb doctor` drift-risk flags on the recipe now also mean the skill may be stale.

---
description: Distill a reusable procedure from this conversation (or a named entry) into kb:/recipes/
argument-hint: [entry-id or path to distill, else current session] [optional name/scope hint]
---

You are extracting a **reusable recipe** ("how we do X") into Gregor's knowledge base.

Source / hint: $ARGUMENTS

- If `$ARGUMENTS` names an entry id or a path, distill **that entry** into a recipe (Read it first).
- Otherwise, distill the **current session's context** (already loaded — do not ask the user to re-summarize).
- Any remaining words are a hint about the recipe's name or scope.

Read `$KB_ENGINE_DIR/librarian/procedure-extract-recipe.md` and follow it exactly. Recipes live
under `kb:/recipes/` and use the `type: recipe` shape in `$KB_ENGINE_DIR/docs/schema.md`.

If the work isn't actually repeatable (a one-off with no reuse value), say so and suggest
`/file-this` instead — don't mint a recipe for it.

# kb-engine

The **engine** for a personal, LLM-managed knowledge base, run through Claude Code. Your KB **content** lives separately in a `kb-data/` directory (created on install) — this repo holds only the machinery.

## Install

```sh
git clone <this repo> && cd kb-engine
./install.sh
```

`install.sh` checks dependencies (`git`, `uv`, `python3`), bootstraps an empty `kb-data/`, symlinks the slash commands into `~/.claude/commands/`, writes `KB_ENGINE_DIR` and `KB_DATA_DIR` into `~/.claude/settings.json`, registers the SessionEnd topic-normalization hook, and installs the git pre-commit validator. It prompts before editing `~/.claude/settings.json`, is **re-runnable**, and supports `--uninstall`.

- Keep content elsewhere: `./install.sh --kb-data /path/to/kb-data`
- Skip the settings prompt: `./install.sh --yes`
- Remove all wiring (content untouched): `./install.sh --uninstall`

Then open a new Claude Code session (or run `/hooks` to reload) and try `/load-kb`.

### Path resolution (no hardcoded paths)

Everything is parameterized by two env vars, written into `~/.claude/settings.json` by the installer so they're present in every session: **`KB_ENGINE_DIR`** (this repo) and **`KB_DATA_DIR`** (your content). Scripts and hooks also self-resolve these from their own on-disk location when the env vars are absent (e.g. the git pre-commit hook, which runs outside a Claude session), so nothing is tied to one machine.

## Layout

- `CLAUDE.md` — what greets Claude when the repo is opened (points at `install.sh`).
- `install.sh` — the installer (global, idempotent, `--uninstall`).
- `docs/schema.md` — the frontmatter contract for leaf entries and `_route.md` files. Read this first.
- `templates/` — starter files for new entries, routes, and the topic vocabulary (`_topics.yaml.template`).
- `commands/` — Claude Code slash commands (`/file-this`, `/find`, `/load-kb`, `/start`, `/promote`, `/split`, `/collapse`, `/dedup`, `/tidy`).
- `librarian/procedure-file.md` — canonical filing procedure shared by the slash command and the headless librarian script.
- `scripts/validate.py` — schema validator. `scripts/audit-topics.py` — topic normalization. `scripts/librarian` — headless maintenance.
- `hooks/normalize-topics.sh` — SessionEnd topic-normalization sweep. `hooks/pre-commit` — schema validator gate. `hooks/session-end.sh` — legacy auto-file (off by default).

## Filing is manual

Filing happens only when you run `/file-this` in a session. There is **no SessionEnd auto-file**: the conversation is filed only when you explicitly ask.

The infrastructure for auto-filing is still in place (`hooks/session-end.sh` + librarian `file` mode + `.no-auto-file` marker logic) — dormant by default. To opt back in, add this `hooks` block to `~/.claude/settings.json`:

```json
"hooks": {
  "SessionEnd": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "$KB_ENGINE_DIR/hooks/session-end.sh"
        }
      ]
    }
  ]
}
```

When the hook is enabled, you can pause it without removing it by `touch kb-data/.no-auto-file` (delete the marker to re-enable).

## Logs

Every headless librarian run (split, collapse, dedup, or — if you re-enable the hook — file) writes to `kb-data/.librarian/log/<timestamp>-<session>-<mode>.md` (gitignored). Tail the most recent:

```sh
ls -t $KB_DATA_DIR/.librarian/log/ | head -1 | \
  xargs -I{} cat $KB_DATA_DIR/.librarian/log/{}
```

## Locking

`kb-data/.librarian.lock` is a directory created via atomic `mkdir`. If a stale lock survives a crash, the next librarian run detects the dead PID and clears it. If two librarians race, the second waits up to 30s then aborts (logs the abort).

## Architecture (short)

- **Knowledge graph.** Folders form a tree; `_route.md` files form a cyclic graph on top via `related` links.
- **Two file types.** Leaf entries (`<date>-<slug>.md`) hold filed conversations. `_route.md` indexes each folder so retrieval can traverse without loading leaves.
- **HOT / WARM / COLD.** Main agent has HOT context (full transcript loaded), WARM (just the entry's summary or a folder's `_route.md`), or COLD (not loaded). The retriever subagent moves things up the temperature scale on demand.
- **Librarian.** Headless Claude run that files conversations, branches when a leaf grows too diverse, dedups, flags contradictions, and runs cleanup passes. One program, multiple modes (slice 2 implements `file`).

See `docs/schema.md` for the frontmatter contract and `librarian/procedure-file.md` for the filing procedure.

### Schema validator (slice 7)

`scripts/validate.py` walks `kb-data/`, parses every `.md` file's YAML frontmatter, and enforces the schema: required fields, ISO 8601 UTC timestamps, `kb:/` URIs that resolve on disk, ids matching filenames, every leaf appearing in its parent route's `entries[]`, etc.

Self-contained via `uv run --script` (PEP 723) — no global PyYAML install needed; uv manages the dependency in a cached ephemeral venv.

```sh
# Manual run
$KB_ENGINE_DIR/scripts/validate.py

# Pre-commit hook in kb-data — install once:
ln -sf $KB_ENGINE_DIR/hooks/pre-commit \
       $KB_DATA_DIR/.git/hooks/pre-commit

# Skip in emergencies (don't make a habit of it):
git commit --no-verify
```

Validator output is one error per line, prefixed with the file's `kb:/` path. Exit code 1 on any error.

## Slice progress

- [x] Slice 1: schema + `/file-this` + `/find`
- [x] Slice 2: SessionEnd hook auto-file + locking + logging *(hook disabled by default — filing is now manual via `/file-this`)*
- [x] Slice 7: validation script + git pre-commit
- [x] Auto-routing at session start (`/start <intent>`)
- [x] Slice 3a: splitting (`/split kb:/folder`)
- [x] Slice 3b: collapse (`/collapse kb:/parent`) + dedup (`/dedup kb:/scope`)
- [x] `/tidy kb:/scope` — runs split + collapse + dedup in sequence
- [x] `/promote <id-or-path>` (slice 5 partial — `/demote` skipped; context is monotonic)
- [ ] Slice 6: staleness + compaction (scheduled)
- [ ] link-fix mode (when path-rewrite bugs surface)

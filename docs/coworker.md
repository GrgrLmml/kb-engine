# Co-worker mode: an always-on personal Claude co-worker

Optional. The rest of kb-engine is a memory for *your* Claude sessions; co-worker
mode adds a machine that keeps working when you don't: routine agents on timers
that research, watch and report, filing everything into the same KB.

The setup has three parts:

1. **The main agent**: an interactive Claude Code session you talk to (in tmux,
   on an always-on box, or just your laptop).
2. **The KB**: its long-term memory and audit trail (this repo).
3. **Routine agents**: narrow headless runs on timers, one job each
   (`scripts/coworker`).

```
            you (terminal / Slack)
                    │
          ┌─────────▼──────────┐        reads/writes        ┌──────────────┐
          │  main agent         │◄─────────────────────────►│  KB (git)     │
          │  interactive Claude │                            │  entries +    │
          └─────────▲──────────┘                            │  dated claims │
                    │ Monitor on events.log                  └──────▲───────┘
          ┌─────────┴──────────┐                                    │ kb file / kb facts
          │  slack-agent        │   ┌───────────────────────────────┴────────┐
          │  (small model,      │   │ routine agents (scripts/coworker run)  │
          │   every 2 min)      │   │ scouts · watches · daily plan · review │
          └─────────────────────┘   └─────────────────────────────────────────┘
```

## Design rules

These are why it works. Keep them when you extend it.

- **One job per agent.** One prompt file, one timer per slot. To add work, add an
  agent; don't make an existing one bigger.
- **The model writes files; the runner does the rest.** A headless run only writes
  in its own run folder: `entry.json`, optionally `slack.txt`, `chart.png`,
  `seen.add`. `coworker run` validates, files to the KB, posts and pushes. The
  model never holds a token: runs get no MCP servers at all.
- **Facts come from the KB, not from prompts.** Prompts describe the *method*.
  What you work on, who the competitors are, what you decided: dated KB claims,
  injected into every run via `kb facts <prefix>`. Change a fact once in the KB
  and every agent picks it up.
- **The KB is the audit trail.** Every run is a KB entry; every claim says when
  and from where.
- **Everything is in git.** The co-worker home (and the KB, unless it opts out
  with `.no-autocommit`) is committed after every run by `coworker sync`, which
  refuses to commit anything token-shaped.
- **Cheapest model that can do the job.** Small model for frequent scans, a
  stronger one for the daily synthesis, the strongest for the weekly fact check.
- **Humans approve risky changes.** Unattended agents read, diagnose and propose.
  Agents never schedule themselves: `coworker schedule` is a command *you* run.

## 1. Install

```bash
./install.sh --coworker                 # or: --coworker --home ~/somewhere
```

On top of the normal install this:

- scaffolds a **co-worker home** (default `~/coworker`, a git repo), your
  private instance:
  ```
  coworker.env        instance config (no secrets)
  agents/_brief.md    house rules shared by every agent
  agents/<name>.md    one prompt per routine agent (frontmatter = its config)
  units/              mirror of the timers you installed
  state/              run folders, logs, cursors (gitignored)
  ```
- writes `COWORKER_HOME` into `~/.claude/settings.json`,
- offers an hourly safety-net `coworker sync` timer,
- on Linux, installs the nightly librarian as a systemd user timer (macOS: launchd).

**On a server:** a small always-on VM (2 vCPU / 4 GB is plenty), a normal user
with SSH-key login, `git jq curl tmux uv`, Node for the Claude CLI
(`npm i -g @anthropic-ai/claude-code`), log in to `claude` once interactively, and
`sudo loginctl enable-linger <user>` so timers run while you're logged out. Give
the box a deploy key for the repos it needs, not a personal token.

Putting the KB inside the home keeps one repo to push:
```bash
git clone git@github.com:<you>/<coworker-home>.git ~/coworker
./install.sh --kb-data ~/coworker/kb --coworker --home ~/coworker
```

## 2. Seed the facts

Before any agent runs, file one entry whose claims describe your work. Subjects
are dotted, `<prefix>.<area>.<thing>.<attribute>`:

```bash
kb file --jot --meta - <<'EOF'
{"title": "What I work on", "folder": "kb:/coworker",
 "folder_purpose": "The co-worker's standing facts and its agents' reports.",
 "summary": "Standing facts every routine agent starts from: what I build, for whom, and the competitors I track.",
 "claims": [
   {"subject": "me.work.what", "value": "…", "since": "2026-10-01", "kind": "reported", "source": "me"},
   {"subject": "me.goals.next-milestone", "value": "…", "since": "2026-10-01", "kind": "reported", "source": "me"},
   {"subject": "me.competitor.acme.what", "value": "…", "since": "2026-10-01", "kind": "observed", "source": "https://…"}
 ]}
EOF
```

Then set `FACTS_PREFIX=me` in `coworker.env`. A later claim on the same subject
supersedes the earlier one (`kb facts me --history`); `kb doctor` flags conflicts.

## 3. Routine agents

### The prompt file

`agents/<name>.md` in the home. The frontmatter is the agent's config; the body
is the method (never facts):

```markdown
---
name: scout
description: Scans the web for news on the topics in KB FACTS.
model: sonnet            # default: DEFAULT_MODEL
budget: 900              # seconds before the run is killed
tools: WebSearch,WebFetch # on top of Read/Write/Edit/Glob/Grep + read-only kb
facts: me                # claim prefixes injected as KB FACTS (default: FACTS_PREFIX)
folder: kb:/coworker/scout   # default: <KB_FOLDER>/<name>
channel: C0123456789     # where slack.txt goes (default: SLACK_DEFAULT_CHANNEL)
escalate: me.competitor. # DM you when a claim names an entity the KB didn't know
context_runs: 3          # previous run summaries shown to the next run
---

Who the agent is and when it runs. What to check, which sources. What counts as
important enough to post (most runs should not). Anything specific about claims.
```

The runner appends the shared brief and the **output contract** (the exact
`entry.json` schema, "never invent facts", "you cannot post") itself, so prompts
stay short. `templates/coworker/example-scout.md` is a starting point.

### What one run does

`coworker run <agent> [slot]`:

1. **Context:** date/time and slot, `KB FACTS` (capped at 60k chars), the last few
   runs' summaries, `seen.tsv` (what was already reported), recent posts.
2. **Run:** fresh folder `state/<agent>/runs/<UTC>-<slot>/`, then
   `claude -p` with the agent's model, the prompt as system prompt, no MCP
   servers, no user settings or hooks (`--setting-sources local`), tools limited
   to the run folder plus read-only `kb facts|search|show`, killed after `budget`.
3. **Validate:** `entry.json` must be a JSON object with a title and a real summary.
4. **File:** `kb file --jot` into the agent's folder (created on first run).
   Sources that are kb ids become `related:` links; claims update the shared facts.
5. **Post:** only if the agent wrote `slack.txt` (with `chart.png` attached if
   present); logged to `posted.log` so later runs don't repeat it.
6. **Escalate:** deterministic, no model: a claim under an `escalate:` prefix that
   names an entity the KB didn't know before the run DMs you.
7. **Push:** `coworker sync "<agent> <slot>: <title>"`.

Every run appends one line to `state/<agent>/runs.log`:
`OK | FAILED | TIMEOUT | INVALID | FILE-FAILED`, with the run folder to look in.

### Adding one

1. Write `agents/<name>.md`.
2. `coworker run <name> --dry-run`: runs the model, prints the payload, files
   nothing. Then `coworker run <name> --no-post`: files to the KB, posts nothing.
   Read the entry (`kb show <id>`).
3. Schedule it yourself:
   ```bash
   coworker schedule scout morning "07:30"
   coworker schedule scout evening "19:30"
   coworker schedule reviewer weekly "Sun 21:30"
   coworker schedule errors hourly "every 1h"
   ```
   `<when>`: `HH:MM` daily, `Mon,Thu HH:MM` / `Sun HH:MM` weekly, `hourly`,
   `every 15m` / `every 6h`. On systemd, times are in `COWORKER_TZ`; launchd uses
   the machine's local time. Missed runs catch up after downtime; pass
   `--no-catch-up` for anything that touches production, so a missed run never
   fires at a random hour. `--dry-run` prints the units without installing.
4. `coworker status` · `coworker unschedule <agent> [slot]` · `coworker unschedule --all`.

### An example schedule

| Agent | Model tier | When | Posts |
|---|---|---|---|
| Slack watcher (daemon) | small | every 2 min | relays human messages to the main agent |
| Error watch | small | hourly | digest, only if there are errors |
| Scout morning/midday/evening | small | 07:30, 13:30, 19:30 | only real news |
| Competitor watch | small | 10:00 | real moves only; new competitor: DM |
| Strategist (rolling plan) | strong | 20:30 | only on a material change |
| Weekly reviewer (fact check, red team) | strongest | Sun 21:30 | always: the weekly brief |
| KB librarian | none (deterministic) | 03:30 UTC | no |
| Sync | none | hourly | no |

## 4. Slack (optional)

- Create a Slack app with a bot user and the scopes `chat:write`,
  `channels:history`, `groups:history`, `im:write`, `files:write`, `users:read`.
  Invite it to the channels it should read or post in.
- Register its token **once**, as an MCP server for the Claude CLI, in the
  directory you run the main agent from (set `SLACK_MCP_CWD` to it):
  ```bash
  claude mcp add slack-mcp -e SLACK_BOT_TOKEN=xoxb-… -e SLACK_TEAM_ID=T… \
    -- npx -y @modelcontextprotocol/server-slack
  ```
  That is the only place the token lives. Scripts read it at run time
  (`SLACK_TOKEN_CMD`), never print it, never write it into a repo.
- Fill in `SLACK_OWNER_ID` (your user id, for DMs), `SLACK_DEFAULT_CHANNEL`,
  `SLACK_BOT_NAME`, `SLACK_TEAM_ID` in `coworker.env`.
- Helpers: `coworker post <channel|user-id> "<text>"`,
  `coworker upload <channel-id> <file> "[comment]"`.
- **Style for every post:** short, specific, no em-dashes, one suggested action.

### The Slack watcher

`scripts/slack-agent` is a cheap background sidekick: each tick fetches new
messages (including thread replies and reactions), a small model triages them
against a brief, and noteworthy ones land as `EVENT …` lines in an event log.
It posts only what the main session queues with `slack-agent say`.

```bash
slack-agent setup main --channels C0123,C0456 --watch U0AAA,U0BBB \
  --brief "Ignore the deploy bot. Track replies to my posts in C0123."
coworker daemon slack-watcher -- "$KB_ENGINE_DIR/scripts/slack-agent" run main --every 120
slack-agent log main -f        # what the main session watches
slack-agent say main C0123 "On it, will report back by 3pm." --thread 1728…
```

## 5. The main agent

The interactive session makes the judgement calls.

- **Where:** `tmux new -s coworker`, then `claude` in your main working directory.
  It starts with the KB map (SessionStart hook), per-prompt recall, and its own
  memory files for standing rules ("prod writes need a go", "deploy named
  branches only").
- **Hearing from Slack:** a `Monitor` on the watcher's `events.log`. Use a
  `wc -l` poll loop every 5 s that prints only new human `EVENT` lines (filter
  out bot user ids); `tail -F | grep` can silently miss lines. Monitors expire
  after 30 min; re-arm on every expiry. Watch other result files the same way
  (e.g. a runs.log for `FAILED|TIMEOUT`).
- **What it does:** answers Slack, does one-off research (subagents for deep
  dives), makes prod changes after your go and files each one, files whole
  sessions with `/file-this`, then `coworker sync`.
- **What it doesn't do:** schedule its own unattended work. It writes the agent
  prompt and tells you the `coworker schedule` line; you run it.

## 6. Agents that touch production

Not shipped as code (too specific to each setup); the pattern:

- **Preflight:** health checks pass (sites 200, services up), then a fresh backup.
- **The change:** narrow (e.g. OS updates only; reboot only if required).
- **Verify:** the same checks as the preflight.
- **On failure, never auto-fix.** Run a fixed read-only forensics script, give its
  output to an advisor agent that can only write a proposal (that is a normal
  `coworker run` agent with no tools beyond its run folder), post it and DM
  yourself. The fix waits for a human.
- **Either way,** file it to an ops-log folder in the KB.
- Schedule it with `--no-catch-up`.

## 7. Operating it

- **Health:** `coworker status`, `state/*/runs.log`, `kb doctor`, `git log` in the
  home (every run and filing is a commit). systemd: `systemctl --user list-timers`;
  launchd: `launchctl list | grep com.kb-engine`.
- **Rebuild the box:** clone kb-engine and your home, `./install.sh --kb-data … 
  --coworker --home …`, `kb sync`, log in to `claude`, re-register the Slack MCP,
  then re-run your `coworker schedule` lines (the `units/` mirror shows what was
  installed).
- **Costs:** model choice × cadence. Prefer fewer, better runs; most runs quiet.
- **Security:** no secrets in the home, prompts, KB entries or Slack; keep
  customer PII out of the KB; unattended agents get read-only tools; production
  changes need your go and are filed.

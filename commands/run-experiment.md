# /run-experiment — execute a pre-registered crucial experiment from the ledger

Run one experiment from the epistemic ledger (`kb:/problems/`), using this session's
real tools (Datadog, BigQuery, Slack, repos), and resolve the problem. This is the
step that closes the conjecture-and-criticism loop: /criticize designs, this command
observes and settles.

Argument (optional): a problem id. `$ARGUMENTS`

Follow the canonical procedure at `$KB_ENGINE_DIR/librarian/procedure-run-experiment.md`
exactly. In short:

1. No id given → `$KB_ENGINE_DIR/scripts/kb problems list --status ready`, pick the
   best decisiveness/cost item, confirm the choice with Gregor.
2. Restate the pre-registered observation + outcomes table verbatim BEFORE touching
   any tool — that contract may not be reinterpreted after seeing data.
3. Make the observation (only that one), map it onto the pre-registered outcomes,
   confirm the verdict with Gregor, then apply: file the run as an episode, update
   the models (`evidence_for` / `refuted_by` / status / rivals), and
   `kb problems resolve <id> --by <episode-id>`.

Never run this headless — it needs Gregor's confirmation to flip a model's status.

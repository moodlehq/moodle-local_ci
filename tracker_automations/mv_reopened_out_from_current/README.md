# mv_reopened_out_from_current

**Tracker automation.** Moves reopened issues out of the current integration queue.

> **⚠️ Mutates live Jira.** This automation transitions issues, edits fields, and/or posts comments on the configured `jiraserver`, and may launch Jenkins jobs. Runs against the real tracker are production impact. Prefer the `quiet`/`dryrun` option (where available) and a test tracker. See [CLAUDE.md](../../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `mv_reopened_out_from_current.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `jiraclicmd` — fill execution path of the jira cli
- `jiraserver` — jira server url we are going to connect to
- `jirauser` — user that will perform the execution
- `jirapass` — password of the user
- `mustfixversion` — fixfor version which will be preserved on reopening

---

See [CLAUDE.md](../../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../../docs/testing.md) for the testing workflow.

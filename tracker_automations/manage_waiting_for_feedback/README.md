# manage_waiting_for_feedback

**Tracker automation.** Manages the 'waiting for feedback' lifecycle for IR and CLR issues (reminders, timeouts).

> **⚠️ Mutates live Jira.** This automation transitions issues, edits fields, and/or posts comments on the configured `jiraserver`, and may launch Jenkins jobs. Runs against the real tracker are production impact. Prefer the `quiet`/`dryrun` option (where available) and a test tracker. See [CLAUDE.md](../../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `manage_waiting_for_feedback.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `jiraclicmd` — fill execution path of the jira cli.
- `jiraserver` — jira server url we are going to connect to.
- `jirauser` — user that will perform the execution.
- `jirapass` — password of the user.
- `daystoreopen` — number of days to proceed to reopen the issue since the issue was sent to WfF.
- `daystoremind` — number of days to proceed to remind about the incoming reopen since the issue was sent to WfF. Default 0 = disabled.

---

See [CLAUDE.md](../../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../../docs/testing.md) for the testing workflow.

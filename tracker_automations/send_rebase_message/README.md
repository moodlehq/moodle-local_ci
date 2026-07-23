# send_rebase_message

**Tracker automation.** Sends the standard rebase message to issues awaiting integration.

> **⚠️ Mutates live Jira.** This automation transitions issues, edits fields, and/or posts comments on the configured `jiraserver`, and may launch Jenkins jobs. Runs against the real tracker are production impact. Prefer the `quiet`/`dryrun` option (where available) and a test tracker. See [CLAUDE.md](../../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `send_rebase_message.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `jiraclicmd` — fill execution path of the jira cli
- `jiraserver` — jira server url we are going to connect to
- `jirauser` — user that will perform the execution
- `jirapass` — password of the user
- `altcommentcandidate` — in case a custom comment wants to be used for candidate queue issues (defaults to standard, fixed one)
- `altcommentcurrent` — in case a custom comment wants to be used for current queue issues (defaults to standard, fixed one)
- `altcomment` — left only for backward compatibility (in case any script is using it). It has been replaced by altcommentcandidate

---

See [CLAUDE.md](../../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../../docs/testing.md) for the testing workflow.

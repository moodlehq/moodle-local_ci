# continuous_manage_queues

**Tracker automation.** Manages the candidates/current integration queues during continuous integration (holds, moves, thresholds).

> **⚠️ Mutates live Jira.** This automation transitions issues, edits fields, and/or posts comments on the configured `jiraserver`, and may launch Jenkins jobs. Runs against the real tracker are production impact. Prefer the `quiet`/`dryrun` option (where available) and a test tracker. See [CLAUDE.md](../../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `continuous_manage_queues.sh`
- `lib.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `jiraclicmd` — fill execution path of the jira cli
- `jiraserver` — jira server url we are going to connect to
- `jirauser` — user that will perform the execution
- `jirapass` — password of the user
- `releasedate` — Release date, used to decide between A (before release) and B (after release) behaviors. YYYY-MM-DD.
- `lastweekdate` — Last week date to decide between 2a - feed current and 2b - held bug issues. (YYY-MM-DD, defaults to release -1w)
- `currentmin` — optional, number of issue under which the current queue will be fed from the candidates one.
- `movemax` — optional, max number of issue that will be moved from candidates to current when under currentmin.
- `dryrun` — don't perfomr any write operation, only reads. Defaults to empty (false).

## Tests

[`tests/continuous_manage_queues_validation.bats`](../../tests/continuous_manage_queues_validation.bats)

---

See [CLAUDE.md](../../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../../docs/testing.md) for the testing workflow.

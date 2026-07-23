# check_marked_as_integrated

**Tracker automation.** Cross-checks issue fixVersions against the actual commits on the major branches.

> **⚠️ Mutates live Jira.** This automation transitions issues, edits fields, and/or posts comments on the configured `jiraserver`, and may launch Jenkins jobs. Runs against the real tracker are production impact. Prefer the `quiet`/`dryrun` option (where available) and a test tracker. See [CLAUDE.md](../../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `check_marked_as_integrated.sh`
- `util.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `jiraclicmd` — fill execution path of the jira cli
- `jiraserver` — jira server url we are going to connect to
- `jirauser` — user that will perform the execution
- `jirapass` — password of the user
- `gitcmd` — git cli path
- `gitdir` — git directory with integration.git repo
- `gitremotename` — integration.git remote name
- `devbranches` — the next major versions ($branch) under development, comma separated. Ordered by release "distance".

---

See [CLAUDE.md](../../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../../docs/testing.md) for the testing workflow.

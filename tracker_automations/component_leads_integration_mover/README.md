# component_leads_integration_mover

**Tracker automation.** Decides whether undecided awaiting-integration issues go to Component Lead Review or Integration Review.

> **⚠️ Mutates live Jira.** This automation transitions issues, edits fields, and/or posts comments on the configured `jiraserver`, and may launch Jenkins jobs. Runs against the real tracker are production impact. Prefer the `quiet`/`dryrun` option (where available) and a test tracker. See [CLAUDE.md](../../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `component_leads_integration_mover.sh`
- `lib.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `jiraclicmd` — fill execution path of the jira cli
- `jiraserver` — jira server url we are going to connect to
- `jirauser` — user that will perform the execution
- `jirapass` — password of the user
- `jsonclrurl` — url to the webservice providing all the groups, components and reviewers data.
- `clearcache` — set it to "true" to force the removal of the (48h) cached groups, components and reviewers data.
- `quiet` — with any value different from "false", don't perform any action in the Tracker.
- `restrictedto` — if set, restrict any comment to that role in the project. Blank means visible to everybody.
- `releasedate` — Release date, used to calculate the freeze period. Improvements and new features will not be moved to CLR during freeze. YYYY-MM-DD.

---

See [CLAUDE.md](../../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../../docs/testing.md) for the testing workflow.

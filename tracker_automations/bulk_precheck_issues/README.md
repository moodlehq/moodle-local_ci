# bulk_precheck_issues

**Tracker automation.** Bulk-runs the prechecker (via a Jenkins job) over queued issues and reports results back to the tracker.

> **⚠️ Mutates live Jira.** This automation transitions issues, edits fields, and/or posts comments on the configured `jiraserver`, and may launch Jenkins jobs. Runs against the real tracker are production impact. Prefer the `quiet`/`dryrun` option (where available) and a test tracker. See [CLAUDE.md](../../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `bulk_precheck_issues.sh`
- `util.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `jiraclicmd` — fill execution path of the jira cli
- `jiraserver` — jira server url we are going to connect to
- `jirauser` — user that will perform the execution
- `jirapass` — password of the user
- `cf_repository` — id for "Pull from Repository" custom field (customfield_XXXXX)
- `cf_branches` — pairs of moodle branch and id for "Pull XXXX Branch" custom field (main:customfield_XXXXX,....)
- `cf_testinginstructions` — id for testing instructions custom field (customfield_XXXXX)
- `criteria` — "awaiting peer review", "awaiting integration", "developer request"
- `informtofiles` — comma separated list of files where each MDL processed will be informed (format MDL-xxxx unixseconds)
- `maxcommitswarn` — Max number of commits accepted per run. Warning if exceeded. Defaults to 10.
- `maxcommitserror` — Max number of commits accepted per run. Error if exceeded. Defaults to 100.
- `quiet` — with any value different from "false", don't perform any action in the Tracker.
- `jenkinsjobname` — job in the server that we are going to execute
- `jenkinsserver` — private jenkins server url (where the prechecker will be executed.
- `publishserver` — public jenkins server url (where result will be available).

---

See [CLAUDE.md](../../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../../docs/testing.md) for the testing workflow.

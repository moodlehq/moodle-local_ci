# bulk_prelaunch_jobs

**Tracker automation.** Launches Jenkins jobs in bulk for a set of tracker issues.

> **⚠️ Mutates live Jira.** This automation transitions issues, edits fields, and/or posts comments on the configured `jiraserver`, and may launch Jenkins jobs. Runs against the real tracker are production impact. Prefer the `quiet`/`dryrun` option (where available) and a test tracker. See [CLAUDE.md](../../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `bulk_prelaunch_jobs.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `jiraclicmd` — full execution path of the jira cli
- `jiraserver` — jira server url we are going to connect to
- `jirauser` — user that will perform the execution
- `jirapass` — password of the user
- `jenkinsserver` — Full URL of the jenkins server where the jobs will be launched.
- `jenkinsauth` — String that defines the method to connect to the jenkins server, can be -ssh
- `cf_repository` — id for "Pull from Repository" custom field (customfield_XXXXX)
- `cf_branches` — comma separated trios of moodle branch, id for "Pull XXXX Branch" custom field and php version.
- `criteria` — "awaiting integration"...
- `schedulemins` — Frecuency (in minutes) of the schedule (cron) of this job. IMPORTANT to ensure that they match or there will be issues processed more than once or skipped.
- `jobtype` — defaulting to "all", allows to just pick one of the available jobs: phpunit, behat-(firefox|chrome|nonjs|all).
- `quiet` — with any value different from "false", don't perform any action in the Tracker.

## Notes

- **Theme classic runs.** `theme_classic` was removed from Moodle 5.3 (`main`) onwards,
  so the `BEHAT_SUITE=classic` jobs are only launched for the branches that still ship
  it. `bulk_prelaunch_jobs.sh` calculates `classicsupported` (and `allsuiteslabel`, used
  by the runs covering all the suites) for every target branch, and the criteria
  `jobs.sh` rely on it: `main` and `MOODLE_503_STABLE` (and up) get no classic jobs,
  older stables keep them.

---

See [CLAUDE.md](../../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../../docs/testing.md) for the testing workflow.

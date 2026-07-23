# remote_branch_checker

**Code checker.** The 'prechecker' aggregator: clones/prepares moodle.git, runs many checkers on a remote branch, and produces a combined 'smurf' report (xml/html), optionally notifying Jira.

> **⚠️ Destructive git operations.** This script performs hard git operations on its working tree (which may include `git reset --hard`, `git clean -dfx`, branch deletion, pushing, or wiping and re-cloning the workspace). Only point it at a disposable clone. See [CLAUDE.md](../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `checkstyle_converter.php`
- `lib.php`
- `remote_branch_checker.sh`
- `remote_branch_reporter.php`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitcmd` — Path to git executable.
- `phpcmd` — Path to php executable.
- `remote` — Remote repo where the branch to check resides.
- `branch` — Remote branch we are going to check.
- `integrateto` — Local branch where the remote branch is going to be integrated.
- `issue` — Issue code that requested the precheck. Empty means that Jira won't be notified.
- `filtering` — Report about only modified lines (default, true), or about the whole files (false)
- `format` — Format of the final smurf file (xml | html). Defaults to html.
- `maxcommitswarn` — Max number of commits accepted per run. Warning if exceeded. Defaults to 10.
- `maxcommitserror` — Max number of commits accepted per run. Error if exceeded. Defaults to 100.
- `rebasewarn` — Max number of days allowed since rebase. Warning if exceeded. Defaults to 20.
- `rebaseerror` — Max number of days allowed since rebase. Error if exceeded. Defaults to 60.
- `npmcmd` — Optional, path to the npm executable (global)
- `pushremote` — (optional) Remote to push the results of prechecker to. Will create branches like MDL-1234-main-shorthash
- `resettocommit` — (optional) Should not be used in production runs. Reset $integrateto to a commit for testing purposes.

## Tests

[`tests/remote_branch_checker.bats`](../tests/remote_branch_checker.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

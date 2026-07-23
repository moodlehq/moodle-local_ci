# compare_databases

**Code checker.** Installs the DB on one branch and upgrades it from another, then compares the two schemas to catch upgrade/install drift.

> **⚠️ Destructive git operations.** This script performs hard git operations on its working tree (which may include `git reset --hard`, `git clean -dfx`, branch deletion, pushing, or wiping and re-cloning the workspace). Only point it at a disposable clone. See [CLAUDE.md](../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `compare_databases.php`
- `compare_databases.sh`
- `run_conditionally.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitcmd` — Path to the git executable
- `phpcmd` — Path to the PHP CLI executable
- `mysqlcmd` — Path to the mysql CLI executable
- `gitdir` — Directory containing git repo
- `gitbranchinstalled` — Branch we are going to install the DB (and upgrade to)
- `gitbranchupgraded` — Branch we are going to upgrade the DB from (supports multiple, separated by commas)
- `dblibrary` — Type of library (native, pdo...)
- `dbtype` — Name of the driver (mysqli...)
- `dbhost1` — DB1 host
- `dbhost2` — DB2 host (optional)
- `dbuser1` — DB1 user
- `dbuser2` — DB2 user (optional)
- `dbpass1` — DB1 password
- `dbpass2` — DB2 password (optional)

## Tests

[`tests/compare_databases.bats`](../tests/compare_databases.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

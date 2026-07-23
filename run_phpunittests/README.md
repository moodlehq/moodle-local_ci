# run_phpunittests

**Environment/setup helper.** Installs the DB and runs PHPUnit for a branch.

## Scripts

- `run_phpunittests.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `phpcmd` — Path to the PHP CLI executable
- `psqlcmd` — Path to the psql CLI executable
- `mysqlcmd` — Path to the mysql/mariadb CLI executable
- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to install the DB
- `dblibrary` — Type of library (native, pdo...)
- `dbtype` — Name of the driver (mysqli...)
- `dbhost` — DB host
- `dbuser` — DB user
- `dbpass` — DB password
- `multipleclassiserror` — Does multiple classes in test file
- `extraconfig` — Extra settings that will be injected ti config.php

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

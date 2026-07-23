# list_valid_components

**Supporting script.** Produces the list of valid Moodle components (needs a running DB/site).

## Scripts

- `list_valid_components.php`
- `list_valid_components.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `phpcmd` — Path to the PHP CLI executable
- `mysqlcmd` — Path to the mysql CLI executable
- `gitdir` — Directory containing git repo
- `dblibrary` — Type of library (native, pdo...)
- `dbtype` — Name of the driver (mysqli...)
- `dbhost` — DB host
- `dbuser` — DB user
- `dbpass` — DB password

## Tests

[`tests/list_valid_components.bats`](../tests/list_valid_components.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

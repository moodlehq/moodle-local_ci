# check_upgrade_savepoints

**Code checker.** Verifies that DB upgrade steps in a branch declare their upgrade savepoints correctly.

## Scripts

- `check_upgrade_savepoints.php`
- `check_upgrade_savepoints.sh`
- `savepoints2checkstyle.php`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `WORKSPACE`
- `phpcmd` — Path to the PHP CLI executable
- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to check

## Tests

[`tests/check_upgrade_savepoints.bats`](../tests/check_upgrade_savepoints.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

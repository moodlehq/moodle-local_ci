# upgrade_external_backup_check

**Code checker.** Checks external backup/restore consistency for changed files.

## Scripts

- `upgrade_external_backup_check.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `WORKSPACE` — Path to the directory where test reults will be sent
- `phpcmd` — Path to the PHP CLI executable
- `gitcmd` — Path to the git CLI executable
- `gitdir` — Directory containing git repo
- `initalcommit`
- `finalcommit`

## Tests

[`tests/upgrade_external_backup.bats`](../tests/upgrade_external_backup.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

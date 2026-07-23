# versions_check_set

**Code checker.** Checks plugin version numbers fall within an allowed range, and can bulk-set versions/requires.

## Scripts

- `versions_check_set.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `WORKSPACE` — Path to the directory where test reults will be sent
- `phpcmd` — Path to the PHP CLI executable
- `gitdir` — Directory containing git repo
- `betweenversions` — Optional, specify the min and max 8digits (YYYYMMDD) allowed. Hyphen separated. Max = min if not specified.
- `setversion` — Optional, 10digits (YYYYMMDD00) to set all versions to. Empty = not set
- `setrequires` — Optional, 10digits (YYYYMMDD00) to set all dependencies to. Empty = $setversion

## Tests

[`tests/versions_check_set.bats`](../tests/versions_check_set.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

# detect_conflicts

**Code checker.** Scans a branch for leftover merge-conflict markers.

## Scripts

- `detect_conflicts.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to examine

## Tests

[`tests/detect_conflicts.bats`](../tests/detect_conflicts.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

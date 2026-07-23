# illegal_whitespace

**Code checker.** Flags illegal/trailing whitespace introduced in a branch.

## Scripts

- `illegal_whitespace.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to examine

## Tests

[`tests/illegal_whitespace.bats`](../tests/illegal_whitespace.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

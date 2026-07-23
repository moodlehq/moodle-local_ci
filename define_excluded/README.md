# define_excluded

**Supporting script.** Emits the list of paths excluded from checks (third-party libs, etc.) in various formats, for other scripts to consume.

## Scripts

- `define_excluded.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to examine
- `format` — Optional, name of the format we want to output (defaults to none)

## Tests

[`tests/define_excluded.bats`](../tests/define_excluded.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

# php_lint

**Code checker.** Runs `php -l` syntax checks (and BOM detection) on changed PHP files.

## Scripts

- `php_lint.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitcmd` — Path to the git CLI executable
- `gitdir` — Directory containing git repo
- `phpcmd` — Path to php CLI exectuable

## Tests

[`tests/php_lint.bats`](../tests/php_lint.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

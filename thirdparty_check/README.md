# thirdparty_check

**Code checker.** Verifies third-party library declarations (thirdpartylibs.xml) for changed files.

## Scripts

- `thirdparty_check.sh`
- `thirdpartylocations.php`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `WORKSPACE` — Path to the directory where test reults will be sent
- `phpcmd` — Path to the PHP CLI executable
- `gitcmd` — Path to the git CLI executable
- `gitdir` — Directory containing git repo
- `initalcommit`
- `finalcommit`

## Tests

[`tests/thirdparty_check.bats`](../tests/thirdparty_check.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

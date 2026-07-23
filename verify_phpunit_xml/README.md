# verify_phpunit_xml

**Code checker.** Verifies `phpunit.xml`/test file layout (e.g. one class per test file).

## Scripts

- `create_phpunit_xml.php`
- `verify_phpunit_xml.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `phpcmd` — Path to the PHP CLI executable
- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to examine
- `multipleclassiserror` — Does multiple classes in test file raise error or just warning (default)

## Tests

[`tests/verify_phpunit_xml.bats`](../tests/verify_phpunit_xml.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

# mustache_lint

**Code checker.** Lints changed Mustache templates: syntax, HTML validity (via a validator), and embedded JS.

## Scripts

- `js_helper.php`
- `mustache_lint.php`
- `mustache_lint.sh`
- `simple_core_component_mustache_loader.php`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitcmd` — Path to the git CLI executable
- `gitdir` — Directory containing git repo
- `phpcmd` — Path to php CLI exectuable
- `validator` — (optional) url for validator - defaults to https://html5.validator.nu

## Tests

[`tests/mustache_lint.bats`](../tests/mustache_lint.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

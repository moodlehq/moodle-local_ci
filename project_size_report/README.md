# project_size_report

**Supporting script.** Reports code-size metrics for the project (uses PEAR/PHP tooling).

## Scripts

- `project_size_report.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to check
- `pearpath` — Path where the pear executables are available
- `phpcmd` — php cli executable

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

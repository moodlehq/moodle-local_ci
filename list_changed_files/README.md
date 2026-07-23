# list_changed_files

**Supporting script.** Lists files changed between two commits; a building block used by most diff-based checkers.

## Scripts

- `list_changed_files.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitcmd` — Path to the git CLI executable
- `gitdir` — Directory containing git repo
- `initialcommit` — hash of the initial commit
- `finalcommit` — hash of the final commit

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

# git_garbage_collector

**Environment/setup helper.** Runs `git gc` (normal or aggressive) on the CI clone every N invocations to keep it healthy.

> **⚠️ Destructive git operations.** This script performs hard git operations on its working tree (which may include `git reset --hard`, `git clean -dfx`, branch deletion, pushing, or wiping and re-cloning the workspace). Only point it at a disposable clone. See [CLAUDE.md](../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `git_garbage_collector.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitcmd` — Path to git executable.
- `gitdir` — Directory containing git repo.
- `gcinterval` — Number of runs before performing a manual gc of the repo. Defaults to 25. 0 means disabled.
- `gcaggressiveinterval` — Number of runs before performing an aggressive gc of the repo. Defaults to 900. 0 means disabled.

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

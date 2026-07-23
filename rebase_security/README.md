# rebase_security

**Environment/setup helper.** Rebases security branches onto integration and pushes them to the security remote.

> **⚠️ Destructive git operations.** This script performs hard git operations on its working tree (which may include `git reset --hard`, `git clean -dfx`, branch deletion, pushing, or wiping and re-cloning the workspace). Only point it at a disposable clone. See [CLAUDE.md](../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `rebase_security.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitcmd` — Path to git executable.
- `gitdir` — Directory containing git repo (will be cloned to if .git doesn't exist)
- `gitbranch` — Branch we are rebasing onto
- `npmcmd` — Optional, path to the npm executable (global)
- `integrationremote` — Remote where integration is being fetched from
- `securityremote` — Remote repo where security branches are being pushed to

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

# git_sync_two_branches

**Environment/setup helper.** Syncs a source branch onto a target branch and pushes the result to a remote.

> **⚠️ Destructive git operations.** This script performs hard git operations on its working tree (which may include `git reset --hard`, `git clean -dfx`, branch deletion, pushing, or wiping and re-cloning the workspace). Only point it at a disposable clone. See [CLAUDE.md](../CLAUDE.md#safety-read-before-running-anything).

## Scripts

- `git_sync_two_branches.sh`
- `lib.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `WORKSPACE` — Path to the workspace directory.
- `gitcmd` — Path to git executable.
- `gitdir` — Directory containing git repo.
- `gitremote` — Remote name where the branches are located. Default: origin.
- `dryrun` — If set to anything, the script will not perform any changes.
- `source` — Source branch to sync from.
- `target` — Target branch to sync to.

## Tests

[`tests/git_sync_two_branches.bats`](../tests/git_sync_two_branches.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

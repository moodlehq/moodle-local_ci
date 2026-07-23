# prepare_npm_stuff

**Environment/setup helper.** Installs the Node/npm tooling (shifter, recess, or package.json deps) needed to build a branch.

## Scripts

- `prepare_npm_stuff.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to install the DB
- `nodecmd` — Optional, path to the node executable (global)
- `npmcmd` — Optional, path to the npm executable (global)
- `gitcmd` — Optional, path to the git executable
- `shifterversion` — Optional, defaults to 0.4.6. Not installed if there is a package.json file (present in 29 and up)
- `recessversion` — Optional, defaults to 1.1.9 (Important! it's the only legacy version working. Older ones

## Tests

[`tests/prepare_npm_stuff.bats`](../tests/prepare_npm_stuff.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

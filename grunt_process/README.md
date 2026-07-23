# grunt_process

**Code checker.** Runs the grunt build and fails if committed built assets (JS/CSS) are out of date.

## Scripts

- `grunt_process.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `WORKSPACE` — Directory where results are saved.
- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to install the DB
- `npmcmd` — Optional, path to the npm executable (global)
- `npminstall` — (optional), if set the script will install nodejs stuff. Else, nodejs managing is external.
- `isplugin` — (optional), if set we are examining a plugin, some exceptions may be applied.

## Tests

[`tests/grunt_process.bats`](../tests/grunt_process.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

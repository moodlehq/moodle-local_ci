# prepare_composer_stuff

**Environment/setup helper.** Installs a branch's Composer dependencies into a per-branch working dir.

## Scripts

- `prepare_composer_stuff.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `phpcmd` — Path to the PHP CLI executable
- `composercmd` — Path to the composer (usually installed globally in the CI server) executable
- `composerdirbase` — Path to the directory where composer will be installed (--working-dir). branch name will be automatically added.
- `gitdir` — Directory containing git repo
- `gitbranch` — Branch we are going to install the DB
- `githuboauthtoken` — Token for accessing gitub without limits.

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.

# Moodle CI local plugin (`local_ci`)

[![Build Status](https://github.com/moodlehq/moodle-local_ci/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/moodlehq/moodle-local_ci/actions/workflows/ci.yml) [![codecov](https://codecov.io/gh/moodlehq/moodle-local_ci/graph/badge.svg?token=0u0rBbFrXj)](https://codecov.io/gh/moodlehq/moodle-local_ci)

`local_ci` is the collection of scripts that Moodle's Continuous Integration servers run
to automate the work that happens around **integration**: linting and checking proposed
code, running tests, and managing the issue queues in the Moodle tracker (Jira).

It is packaged as a Moodle plugin (it has a `version.php` and the component name
`local_ci`), but it contains almost no runtime Moodle code. In practice it is a
**library of standalone scripts** — mostly Bash, some PHP — each living in its own
top-level directory. There is no single entry point: CI jobs invoke individual scripts
and pass configuration through **environment variables**.

> **Working in this repo (human or AI agent)?** Read [AGENTS.md](AGENTS.md) for the
> conventions, architecture, and safety notes, and [docs/testing.md](docs/testing.md)
> for how to run and write the tests.

## Script families

The scripts group into three families:

- **Code checkers** — run against a checkout of `moodle.git`, usually inspecting the diff
  between two commits: `php_lint`, `mustache_lint`, `illegal_whitespace`,
  `verify_commit_messages`, `check_upgrade_savepoints` and friends. The aggregator is
  [`remote_branch_checker`](remote_branch_checker/) (the "prechecker"), which runs many of
  the others and emits a combined "smurf" report.
- **Tracker automations** — [`tracker_automations/*`](tracker_automations/) manage the Jira
  integration queues via the Jira CLI, sharing configuration through the repo-root
  [`jira.sh`](jira.sh). **They mutate live Jira** — see [Safety](#safety).
- **Environment / setup helpers** — prepare or maintain the tree the checks run in:
  `prepare_composer_stuff`, `prepare_npm_stuff`, `run_phpunittests`,
  `git_garbage_collector`, `git_sync_two_branches`, `rebase_security`.

👉 **[`docs/scripts.md`](docs/scripts.md) is the full catalogue** — every script, what it
does, whether it is destructive, and which test covers it.

## How scripts are configured and run

Each script declares its inputs as environment variables in a comment block at the top,
validates the required ones, and exits non-zero on failure. For example:

```bash
export gitcmd=git phpcmd=php
export gitdir=/path/to/moodle
export GIT_PREVIOUS_COMMIT=<sha> GIT_COMMIT=<sha>
./php_lint/php_lint.sh
```

The actual values, and which job runs which script, are configured **outside this repo**
on the CI servers. You can run any script standalone, or under an orchestrator such as:

- Jenkins — <https://www.jenkins.io/>
- GitHub Actions — <https://docs.github.com/actions>
- Travis — <https://docs.travis-ci.com/user/languages/php/>
- Docker (`moodlehq/moodle-php-apache`) — <https://github.com/moodlehq/moodle-php-apache>

## Dependencies

- A checkout of `moodle.git` for the checkers to run against.
- PHP CLI (many checks) and, for some, a MySQL Moodle site up and running.
- Third-party tools for some checks (PHPUnit, etc.).
- The `local_moodlecheck` local plugin (declared in `version.php`).
- Composer and npm dependencies — run `composer install` and `npm install` regularly.
  Key ones: `moodlehq/moodle-cs` (the coding-style standard) and `vnu-jar` (HTML validator).

## Testing

Tests are [bats](https://github.com/bats-core/bats-core) suites in `tests/`, run by CI as
one job per `*.bats` file against a fresh `moodle.git` clone and MySQL. To run locally:

```bash
composer install && npm install
export LOCAL_CI_TESTS_CACHEDIR=/tmp/ci-cache
export LOCAL_CI_TESTS_GITDIR=/path/to/throwaway/moodle   # DESTRUCTIVE — dedicated clone!
export LOCAL_CI_TESTS_PHPCS_DIR="$PWD/vendor/moodlehq/moodle-cs/moodle"
mkdir -p "$LOCAL_CI_TESTS_CACHEDIR"
bats tests/php_lint.bats        # a single suite
```

See [docs/testing.md](docs/testing.md) for the full list of variables, fixtures, and how
to add a new test.

## Safety

Some scripts are **destructive or outward-facing** and should never be pointed at
production or a shared checkout without care:

- `tracker_automations/*` **change live Jira** (transitions, comments, custom fields) and
  can launch Jenkins jobs. Most support a `quiet`/`dryrun` mode — use it when testing.
- Checkers and setup helpers perform hard git operations on their working tree
  (`git reset --hard`, `git clean -dfx`, and in some cases wiping and re-cloning the
  workspace). The test clone (`LOCAL_CI_TESTS_GITDIR`) is treated as disposable for this
  reason.
- `rebase_security` and `git_sync_two_branches` push to remotes.

## License

GPL-3.0-or-later. Copyright 2012 onwards Eloy Lafuente (stronk7) and contributors.

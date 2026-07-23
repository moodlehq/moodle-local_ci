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

> **Working in this repo (human or AI agent)?** Read [CLAUDE.md](CLAUDE.md) for the
> conventions, architecture, and safety notes, and [docs/testing.md](docs/testing.md)
> for how to run and write the tests.

## Script families

Every directory documents itself in its own `README.md`. They group into three families:

### Code checkers
Run against a checkout of `moodle.git`, usually inspecting the diff between two commits.

| Directory | Checks |
|-----------|--------|
| [`php_lint`](php_lint/) | PHP syntax (and BOM) of changed files. |
| [`mustache_lint`](mustache_lint/) | Mustache templates (syntax, HTML validity, JS). |
| [`illegal_whitespace`](illegal_whitespace/) | Trailing/illegal whitespace. |
| [`verify_commit_messages`](verify_commit_messages/) | Commit message rules & AMOS syntax. |
| [`verify_phpunit_xml`](verify_phpunit_xml/) | Correct `phpunit.xml` / test file layout. |
| [`check_upgrade_savepoints`](check_upgrade_savepoints/) | Upgrade savepoint correctness. |
| [`thirdparty_check`](thirdparty_check/) | Third-party library declarations. |
| [`versions_check_set`](versions_check_set/) | Plugin version numbers within allowed range. |
| [`detect_conflicts`](detect_conflicts/) | Leftover merge-conflict markers. |
| [`compare_databases`](compare_databases/) | Install-vs-upgrade DB schema differences. |
| [`upgrade_external_backup_check`](upgrade_external_backup_check/) | External backup / restore consistency. |
| [`remote_branch_checker`](remote_branch_checker/) | **Aggregator ("prechecker")** — runs many checkers on a branch and emits a combined "smurf" report. |

### Tracker automations
`tracker_automations/*` manage the Jira integration queues via the Jira CLI. They share
configuration through the repo-root [`jira.sh`](jira.sh). **They mutate live Jira** — see
[Safety](#safety). Examples: move issues into/out of current integration, close tested
issues, send rebase messages, manage "waiting for feedback", set integration priorities,
and produce cycle statistics.

### Environment / setup helpers
| Directory | Purpose |
|-----------|---------|
| [`prepare_composer_stuff`](prepare_composer_stuff/) | Install Composer dependencies for a branch. |
| [`prepare_npm_stuff`](prepare_npm_stuff/) | Install Node/npm tooling for a branch. |
| [`run_phpunittests`](run_phpunittests/) | Install DB and run PHPUnit. |
| [`grunt_process`](grunt_process/) | Verify built assets (grunt) are up to date. |
| [`git_garbage_collector`](git_garbage_collector/) | Periodic `git gc` of the CI clone. |
| [`git_sync_two_branches`](git_sync_two_branches/) | Sync one branch onto another. |
| [`rebase_security`](rebase_security/) | Rebase & push security branches. |

Supporting pieces: [`list_changed_files`](list_changed_files/),
[`list_valid_components`](list_valid_components/), [`define_excluded`](define_excluded/),
[`diff_extract_changes`](diff_extract_changes/),
[`generate_component_ant_files`](generate_component_ant_files/),
[`project_size_report`](project_size_report/), [`phplib`](phplib/) (shared PHP CLI
helpers), [`groovyscripts`](groovyscripts/) & [`jenkins_cli`](jenkins_cli/) (Jenkins-side
helpers), [`tracker_content_gadget`](tracker_content_gadget/) (tracker HTML gadgets),
and [`travis`](travis/).

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

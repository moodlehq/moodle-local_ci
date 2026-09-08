# Testing & contributing guide

This document explains how the `local_ci` test suite works, how to run it locally, and
how to add a new check script or test. For the high-level architecture and conventions,
see [AGENTS.md](../AGENTS.md).

## Test framework

Tests are written with **[bats](https://github.com/bats-core/bats-core)** (Bash
Automated Testing System). Each suite is a `tests/<name>.bats` file. The bulk of the
scripts here are Bash, and bats lets us assert on their **stdout/stderr and exit codes**
after running them against a real Moodle git clone.

Layout:

```
tests/
├── <name>.bats            # one suite per feature/script
├── setup.bats             # environment sanity checks (GNU tools, phpcs, git…)
├── libs/
│   ├── shared_setup.bash  # shared helpers, loaded by every suite
│   ├── bats-support/      # vendored bats helper library
│   └── bats-assert/       # vendored bats assertion library
└── fixtures/              # patches & data applied during tests
```

## Required environment variables

The shared setup (`tests/libs/shared_setup.bash`) refuses to run unless these are set:

| Variable | Meaning |
|----------|---------|
| `LOCAL_CI_TESTS_CACHEDIR` | A directory bats can use as a cache. Must exist. |
| `LOCAL_CI_TESTS_GITDIR` | A clone of `moodle.git` to test against. **⚠️ Tests make destructive git changes to it** (`checkout`, `clean -fdx`, `reset --hard`, applying patches). Use a dedicated throwaway clone — never your working checkout. |
| `LOCAL_CI_TESTS_PHPCS_DIR` | Path to the moodle-cs coding standard (after `composer install`, that is `vendor/moodlehq/moodle-cs/moodle`). |

Database-backed suites (e.g. `compare_databases`, `list_valid_components`) additionally
need: `LOCAL_CI_TESTS_DBLIBRARY`, `LOCAL_CI_TESTS_DBTYPE`, `LOCAL_CI_TESTS_DBHOST`,
`LOCAL_CI_TESTS_DBUSER`, `LOCAL_CI_TESTS_DBPASS`.

The setup also exports the tool commands used by scripts (`gitcmd=git`, `phpcmd=php`,
`mysqlcmd=mysql`), sets `LANG=C`, and creates a `WORKSPACE` under `$BATS_TMPDIR`.

## Running locally

```bash
# 1. Install dependencies (provides phpcs / moodle-cs and vnu-jar).
composer install
npm install

# 2. Point the tests at a disposable moodle.git clone.
git clone https://github.com/moodle/moodle.git /path/to/throwaway/moodle

# 3. Configure the environment.
export LOCAL_CI_TESTS_CACHEDIR=/tmp/ci-cache
export LOCAL_CI_TESTS_GITDIR=/path/to/throwaway/moodle
export LOCAL_CI_TESTS_PHPCS_DIR="$PWD/vendor/moodlehq/moodle-cs/moodle"
mkdir -p "$LOCAL_CI_TESTS_CACHEDIR"

# 4. Run a single suite (recommended while developing)...
bats tests/php_lint.bats

# ...or the whole lot.
bats tests/
```

Run bats **from the repository root** — some suites rely on `$PWD` to locate the
`local_ci` base. `git` must have a `user.name`/`user.email` configured, because some
scripts (and `git am`) perform commits.

## How CI runs them

`.github/workflows/ci.yml` runs on every push/PR:

1. **collect** — finds every `tests/*.bats` file (excluding `libs/`) and builds a matrix.
2. **test** — one job per suite. Each job checks out `local_ci` and a full `moodle.git`
   clone, starts MySQL 8, sets up PHP 8.3 + Node (from moodle's `.nvmrc`), runs
   `composer install` and `npm install`, installs bats + support/assert libs, then runs
   `bats --timing tests/<suite>.bats`.
3. **coverage** — the same matrix under `kcov`, uploading to Codecov.

Because each suite is isolated in its own job against a fresh clone, tests may safely make
destructive changes to their `moodle.git` checkout.

## Anatomy of a test

From `tests/php_lint.bats`:

```bash
load libs/shared_setup

setup () {
    create_git_branch MOODLE_402_STABLE v4.2.1     # reset the clone to a known tag
}

@test "php_lint: lib/moodlelib.php lint error detected" {
    git_apply_fixture 402-php_lint-bad.patch        # apply a patch, recording before/after SHAs
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run php_lint/php_lint.sh                      # run the script from repo root, capture output

    assert_failure                                   # from bats-assert
    assert_output --partial "lib/moodlelib.php - ERROR:"
    assert_output --regexp "PHP syntax errors found."
}
```

### Helpers (`tests/libs/shared_setup.bash`)

| Helper | What it does |
|--------|--------------|
| `create_git_branch <branch> <resetto>` | Cleans the clone and hard-resets a branch to a tag/commit, so each test starts from a known state. Sets `$gitbranch`. |
| `git_apply_fixture <patch>` | `git am` a patch from `tests/fixtures/`, exporting `FIXTURE_HASH_BEFORE` and `FIXTURE_HASH_AFTER` for use as `GIT_PREVIOUS_COMMIT`/`GIT_COMMIT`. |
| `ci_run <path/to/script.sh>` | Runs a script relative to the repo root (via `bash -c`, so pipes work) and captures output/status for `assert_*`. |
| `clean_workspace_directory` | Resets `$WORKSPACE`. |

Assertions come from the vendored **bats-assert** library: `assert_success`,
`assert_failure`, `assert_output --partial|--regexp`, etc.

## Fixtures

`tests/fixtures/` holds the inputs tests apply. Most are **git patches** produced with
`git format-patch` and applied with `git am`, named `<branch>-<topic>-<variant>.patch`
(e.g. `402-php_lint-bad.patch`, `31-mustache_lint-ok.patch`). The numeric prefix is the
Moodle branch/version the patch is built against; `setup()` resets the clone to a matching
tag before applying. Some fixtures are plain data files (`31-valid_components.txt`) or
have their own subdirectory (`fixtures/remote_branch_reporter/`).

To create a new fixture: reset your throwaway clone to the target tag, make the change,
`git commit`, then `git format-patch -1` and move the resulting patch into
`tests/fixtures/` with a descriptive name.

## Adding a new check script

1. Create a directory `my_check/` with `my_check.sh`.
2. Follow the [conventions in AGENTS.md](../AGENTS.md#conventions-every-script-follows):
   - Document env vars in a header comment under the shebang.
   - `set -e`, then the `required="..."` validation loop.
   - Defaults via `var=${var:-default}`; locate self with `mydir=...`; call siblings by
     relative path.
3. Add a row for it in [`scripts.md`](scripts.md). Do **not** add a per-directory
   `README.md` — env vars are documented once, in the script header.
4. Add `tests/my_check.bats` and any needed fixtures. CI will pick the new suite up
   automatically (the matrix is generated from the `*.bats` files).
5. Run `bats tests/my_check.bats` locally with the environment configured.

## ⚠️ Safety reminder

Tests are destructive **by design** on `LOCAL_CI_TESTS_GITDIR`. Never set it to a clone
you care about. Do not run `tracker_automations/*` scripts as part of ad-hoc testing
against a real Jira server — they mutate live issues; use their `quiet`/`dryrun` options
and a test tracker. See the [Safety section of AGENTS.md](../AGENTS.md#safety-read-before-running-anything).

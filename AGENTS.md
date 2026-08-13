# AGENTS.md — agent guide for `moodle-local_ci`

This file orients an AI agent (or a new human) working in this repository. Read it
before making changes. For the human-facing overview see [README.md](README.md); for
the testing workflow see [docs/testing.md](docs/testing.md).

## What this repo is

`local_ci` is the collection of scripts that **Moodle's CI servers run to automate
integration**. Despite shipping as a Moodle plugin (`version.php`, component
`local_ci`), it contains almost no runtime Moodle code. It is a **script library**:
each top-level directory is one self-contained "check" or "automation" that a CI job
(historically Jenkins, also GitHub Actions and Travis) invokes.

There is **no single entry point**. Jobs pick individual scripts and pass configuration
through **environment variables**. The orchestration (which job runs which script,
with which values) lives *outside* this repo, on the CI servers.

## The three script families

1. **Code checkers** — run against a checkout of `moodle.git`. They inspect the diff
   between two commits (or a whole branch) and report problems. Examples: `php_lint`,
   `mustache_lint`, `illegal_whitespace`, `verify_commit_messages`,
   `verify_phpunit_xml`, `check_upgrade_savepoints`, `thirdparty_check`,
   `versions_check_set`. The aggregator is `remote_branch_checker` (the "prechecker"),
   which runs many checkers and emits a combined "smurf" report (xml/html).

2. **Tracker automations** (`tracker_automations/*`) — manage the Jira integration
   queues via the Jira CLI. They move issues between queues, close tested issues, send
   rebase messages, set integration priorities, etc. **These mutate live Jira.** See
   the safety section below.

3. **Environment / setup helpers** — prepare or maintain the working tree:
   `prepare_composer_stuff`, `prepare_npm_stuff`, `git_garbage_collector`,
   `git_sync_two_branches`, `run_phpunittests`, `rebase_security`.

[`docs/scripts.md`](docs/scripts.md) is the catalogue: what every script does, which
family it belongs to, whether it is destructive, and which bats suite covers it. Start
there to find the right script, then read that script's own header comment — the header
is the canonical reference for its environment variables, and it lives next to the code.

## Conventions every script follows

When editing or adding a script, match these exactly — the tests and CI depend on them.

- **Configuration is via environment variables**, documented in a comment block right
  under the shebang. Example (`php_lint/php_lint.sh`):
  ```bash
  #!/usr/bin/env bash
  # $gitcmd: Path to the git CLI executable
  # $gitdir: Directory containing git repo
  # $phpcmd: Path to php CLI executable
  ```
- **Required vars are validated up front** with this idiom — keep it:
  ```bash
  set -e
  required="gitcmd gitdir phpcmd"
  for var in $required; do
      if [ -z "${!var}" ]; then
          echo "Error: ${var} environment variable is not defined. See the script comments."
          exit 1
      fi
  done
  ```
- **Optional vars get defaults** with `var=${var:-default}`.
- **`set -e`** at the top; scripts exit non-zero on failure so CI can detect it.
- **Locate self** with `mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"` and
  call sibling scripts by **relative path** (e.g. `${mydir}/../list_changed_files/list_changed_files.sh`).
- **Diff-based checkers** read `GIT_PREVIOUS_COMMIT` / `GIT_COMMIT` (Jenkins-provided)
  and typically fall back to a full scan when they are absent.
- **Tool binaries are parameterised** (`$gitcmd`, `$phpcmd`, `$mysqlcmd`, `$npmcmd`…)
  rather than hardcoded, so CI can pin versions.
- **Tracker scripts source shared Jira config** from the repo-root `jira.sh`
  (`source "${mydir}/../../jira.sh"`), which centralises custom-field names, saved
  filters, and builds `$basereq` from `jiraclicmd/jiraserver/jirauser/jirapass`.
- Common vars: `WORKSPACE` (job working dir, results written here), `gitdir`,
  `gitbranch`, `phpcmd`, `gitcmd`, `mysqlcmd`, `npmcmd`.

## Testing

Tests are **[bats](https://github.com/bats-core/bats-core)** in `tests/*.bats`. See
[docs/testing.md](docs/testing.md) for the full workflow. Essentials:

- Helpers live in `tests/libs/shared_setup.bash` (`create_git_branch`,
  `git_apply_fixture`, `ci_run`). `ci_run some_dir/script.sh` runs a script relative to
  the repo root and captures output for bats `assert_*`.
- Tests apply **patch fixtures** from `tests/fixtures/` (named `<branch>-<topic>.patch`)
  onto a real `moodle.git` clone, then assert on script output/exit code.
- Required env before running: `LOCAL_CI_TESTS_CACHEDIR`, `LOCAL_CI_TESTS_GITDIR`
  (a **dedicated, throwaway** moodle.git clone — tests make destructive git changes to
  it), `LOCAL_CI_TESTS_PHPCS_DIR` (path to the moodle-cs standard), and the
  `LOCAL_CI_TESTS_DB*` vars for DB-backed checks.
- CI (`.github/workflows/ci.yml`) discovers every `*.bats` file and runs one matrix job
  per file, against a fresh moodle.git clone + MySQL 8, with `composer install` and
  `npm install` done first.
- Run a single suite locally: `bats tests/php_lint.bats` (with the env vars set). Run
  from the repo root — some tests use `$PWD` to find the `local_ci` base.

## Safety: read before running anything

Many scripts perform **destructive or outward-facing actions**. Do not run them
casually, and never point them at production or a shared checkout.

- **`tracker_automations/*` mutate live Jira** — they transition issues, add comments,
  change custom fields, and can trigger Jenkins jobs. Most accept a `quiet` var
  (`quiet` != `false` → no tracker changes) or a `dryrun`/`debug` mode — use it. Treat
  any run against the real `jiraserver` as production impact.
- **Checker/setup scripts do destructive git operations** on `$gitdir`/`$WORKSPACE`:
  `git reset --hard`, `git clean -dfx`, branch deletion, and even
  `rm -fr "${WORKSPACE}/"` + fresh clone (`remote_branch_checker`, `rebase_security`).
  The test `LOCAL_CI_TESTS_GITDIR` clone is expected to be sacrificial for this reason.
- **`rebase_security` / `git_sync_two_branches` push to remotes.** `git_sync_two_branches`
  has a `dryrun` var; prefer it.
- Some scripts make **network calls** (mustache_lint hits an HTML validator; composer/npm
  fetch packages; tracker scripts hit Jira/Jenkins).

When in doubt: read the script's header comment, check its row in
[`docs/scripts.md`](docs/scripts.md), run the bats test instead of the script, and confirm
with the user before any live/tracker run.

## Where things live

| Path | What |
|------|------|
| `<check>/` (top level) | One script each; env vars documented in its header comment. |
| `docs/scripts.md` | Catalogue of every script: purpose, family, safety, tests. |
| `tracker_automations/` | Jira queue automations; shared config in root `jira.sh`. See its `README.md`. |
| `jira.sh` | Shared Jira CLI config (custom fields, filters, `$basereq`). |
| `phplib/clilib.php` | Moodle CLI helper functions reused by PHP scripts. |
| `remote_branch_checker/` | The prechecker aggregator + smurf/checkstyle reporting (`xslt/`). |
| `tests/` | bats suites, `libs/` helpers, `fixtures/` patches. |
| `groovyscripts/`, `jenkins_cli/` | Jenkins-side helpers (Groovy init scripts, CLI jar). |
| `tracker_content_gadget/` | Static HTML gadgets embedded in the Jira tracker. |
| `lang/en/` | Moodle plugin language strings. |
| `.github/workflows/ci.yml` | The bats matrix CI. |
| `version.php` | Moodle plugin metadata (component `local_ci`). |

## Making changes — checklist

1. Match the conventions above (env-var config, `required` guard, `set -e`, relative
   sibling calls).
2. Update the script's header comment if behaviour or variables change — it is the only
   place env vars are documented, so keep it accurate. Add a row to
   [`docs/scripts.md`](docs/scripts.md) only when adding, removing or repurposing a script.
3. Add/adjust a bats test in `tests/` and, if needed, a fixture in `tests/fixtures/`.
   Fixtures are `git format-patch`-style patches applied with `git am`.
4. Run the relevant `bats tests/<suite>.bats` locally before proposing changes.
5. Never introduce hardcoded paths, servers, or credentials — parameterise via env vars.

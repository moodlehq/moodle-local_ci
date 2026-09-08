# Script catalogue

Every top-level directory in this repo is one self-contained CI script (or a small group
of them). This page is the map: what each one does, which family it belongs to, whether
it is destructive, and which bats suite covers it.

**Configuration is not documented here.** Each script declares its environment variables
in a comment block directly under its shebang — that header is the canonical reference and
lives next to the code it describes. Read it before running anything:

```bash
head -20 remote_branch_checker/remote_branch_checker.sh
```

See [AGENTS.md](../AGENTS.md) for the conventions all these scripts follow, and
[testing.md](testing.md) for the test workflow.

## Legend

| Mark | Meaning |
|------|---------|
| 🔶 **git** | Performs destructive git operations on its working tree (`reset --hard`, `clean -dfx`, branch deletion, and in some cases wiping/re-cloning the workspace) and/or pushes to a remote. Point it only at a disposable clone. |
| 🔺 **jira** | Mutates the live tracker: transitions issues, edits custom fields, posts comments, and may launch Jenkins jobs. Prefer `quiet`/`dryrun` and a test tracker. |

Full detail in [AGENTS.md](../AGENTS.md#safety-read-before-running-anything).

## Code checkers

Run against a checkout of `moodle.git`, usually inspecting the diff between two commits
(`GIT_PREVIOUS_COMMIT`/`GIT_COMMIT`), falling back to a full scan when those are absent.

| Script | What it checks | | Tests |
|--------|----------------|---|-------|
| [`remote_branch_checker`](../remote_branch_checker/) | The **"prechecker"** aggregator: prepares a clone, runs many of the checkers below against a remote branch, and produces a combined "smurf" report (xml/html), optionally notifying Jira. | 🔶 | [`remote_branch_checker`](../tests/remote_branch_checker.bats), [`remote_branch_reporter`](../tests/remote_branch_reporter.bats) |
| [`php_lint`](../php_lint/) | PHP syntax (`php -l`) and BOM characters in changed PHP files. | | [`php_lint`](../tests/php_lint.bats) |
| [`mustache_lint`](../mustache_lint/) | Changed Mustache templates: syntax, HTML validity (via a validator service), embedded JS. | | [`mustache_lint`](../tests/mustache_lint.bats), [`mustache_lint_plugins`](../tests/mustache_lint_plugins.bats) |
| [`illegal_whitespace`](../illegal_whitespace/) | Illegal/trailing whitespace introduced in a branch. | | [`illegal_whitespace`](../tests/illegal_whitespace.bats) |
| [`verify_commit_messages`](../verify_commit_messages/) | Commit messages against Moodle rules (issue code, line length) and AMOS script syntax. | | [`verify_commit_messages`](../tests/verify_commit_messages.bats) |
| [`verify_phpunit_xml`](../verify_phpunit_xml/) | `phpunit.xml` and test-file layout (e.g. one class per test file). | | [`verify_phpunit_xml`](../tests/verify_phpunit_xml.bats) |
| [`check_upgrade_savepoints`](../check_upgrade_savepoints/) | That DB upgrade steps declare their upgrade savepoints correctly. | | [`check_upgrade_savepoints`](../tests/check_upgrade_savepoints.bats) |
| [`thirdparty_check`](../thirdparty_check/) | Third-party library declarations (`thirdpartylibs.xml`) for changed files. | | [`thirdparty_check`](../tests/thirdparty_check.bats) |
| [`versions_check_set`](../versions_check_set/) | Plugin version numbers fall in an allowed range; can also bulk-set versions/requires. | | [`versions_check_set`](../tests/versions_check_set.bats) |
| [`detect_conflicts`](../detect_conflicts/) | Leftover merge-conflict markers. | | [`detect_conflicts`](../tests/detect_conflicts.bats) |
| [`grunt_process`](../grunt_process/) | Runs the grunt build and fails if committed built assets (JS/CSS) are stale. | | [`grunt_process`](../tests/grunt_process.bats) |
| [`upgrade_external_backup_check`](../upgrade_external_backup_check/) | External backup/restore consistency for changed files. | | [`upgrade_external_backup`](../tests/upgrade_external_backup.bats) |
| [`compare_databases`](../compare_databases/) | Installs the DB on one branch, upgrades it from another, and compares the schemas to catch install-vs-upgrade drift. | 🔶 | [`compare_databases`](../tests/compare_databases.bats) |

## Tracker automations

Manage the Jira integration queues. All of them source the shared config in
[`jira.sh`](../jira.sh) — see [`tracker_automations/README.md`](../tracker_automations/README.md)
for that contract and the common variables. **Every one of these is 🔺 jira.**

| Script | What it does |
|--------|--------------|
| [`continuous_manage_queues`](../tracker_automations/continuous_manage_queues/) | Manages candidates/current queues during continuous integration (holds, moves, thresholds). Validated by [`continuous_manage_queues_validation`](../tests/continuous_manage_queues_validation.bats). |
| [`normal_manage_queues`](../tracker_automations/normal_manage_queues/) | Manages the queues during normal (non-continuous) periods. |
| [`move_to_current_integration`](../tracker_automations/move_to_current_integration/) | Moves awaiting-integration issues into current integration (clears integrator/date, sets the flag, comments, drops the `ci` label). |
| [`mv_reopened_out_from_current`](../tracker_automations/mv_reopened_out_from_current/) | Moves reopened issues out of the current integration queue. |
| [`component_leads_integration_mover`](../tracker_automations/component_leads_integration_mover/) | Decides whether undecided awaiting-integration issues go to Component Lead Review or Integration Review. |
| [`close_tested_issues`](../tracker_automations/close_tested_issues/) | Transitions tested issues to closed/fixed, clears integration fields, comments. |
| [`progress_automated_tested`](../tracker_automations/progress_automated_tested/) | Advances cibot/untested issues through testing-in-progress to tested. |
| [`delay_awaiting_issues`](../tracker_automations/delay_awaiting_issues/) | Officially delays issues still awaiting integration (clears current flag, sets priority, comments). |
| [`manage_waiting_for_feedback`](../tracker_automations/manage_waiting_for_feedback/) | Manages the "waiting for feedback" lifecycle for IR and CLR issues (reminders, timeouts). |
| [`send_rebase_message`](../tracker_automations/send_rebase_message/) | Sends the standard rebase message to issues awaiting integration. |
| [`check_marked_as_integrated`](../tracker_automations/check_marked_as_integrated/) | Cross-checks issue fixVersions against the actual commits on the major branches. |
| [`set_integration_priority_to_one`](../tracker_automations/set_integration_priority_to_one/) | Raises integration priority to 1 for issues that need it. |
| [`set_integration_priority_to_zero`](../tracker_automations/set_integration_priority_to_zero/) | Lowers integration priority to 0 for issues that need it. |
| [`remove_ci_label_from_waiting_integration`](../tracker_automations/remove_ci_label_from_waiting_integration/) | Removes the `ci` label from newly awaiting-integration issues, to trigger prechecks. |
| [`remove_ci_label_from_wip`](../tracker_automations/remove_ci_label_from_wip/) | Removes the `ci` label from reopened/in-development issues. |
| [`bulk_precheck_issues`](../tracker_automations/bulk_precheck_issues/) | Bulk-runs the prechecker (via a Jenkins job) over queued issues and reports results back to the tracker. |
| [`bulk_prelaunch_jobs`](../tracker_automations/bulk_prelaunch_jobs/) | Launches Jenkins jobs in bulk for a set of tracker issues. |
| [`count_delayed_last_cycle`](../tracker_automations/count_delayed_last_cycle/) | Statistics: issues delayed since the last integration cycle started. |
| [`count_reopened_last_cycle`](../tracker_automations/count_reopened_last_cycle/) | Statistics: issues reopened during the last integration cycle. |
| [`count_test_failed_last_cycle`](../tracker_automations/count_test_failed_last_cycle/) | Statistics: test-failed issues during the last integration cycle. |

## Environment / setup helpers

Prepare or maintain the working tree the checks run in.

| Script | What it does | | Tests |
|--------|--------------|---|-------|
| [`prepare_composer_stuff`](../prepare_composer_stuff/) | Installs a branch's Composer dependencies into a per-branch working dir. | | |
| [`prepare_npm_stuff`](../prepare_npm_stuff/) | Installs the Node/npm tooling (shifter, recess, or `package.json` deps) needed to build a branch. | | [`prepare_npm_stuff`](../tests/prepare_npm_stuff.bats) |
| [`run_phpunittests`](../run_phpunittests/) | Installs the DB and runs PHPUnit for a branch. | | |
| [`git_garbage_collector`](../git_garbage_collector/) | Runs `git gc` (normal or aggressive) on the CI clone every N invocations. | 🔶 | |
| [`git_sync_two_branches`](../git_sync_two_branches/) | Syncs a source branch onto a target branch and pushes the result to a remote. Has a `dryrun`. | 🔶 | [`git_sync_two_branches`](../tests/git_sync_two_branches.bats) |
| [`rebase_security`](../rebase_security/) | Rebases security branches onto integration and pushes them to the security remote. | 🔶 | |

## Supporting scripts

Building blocks the checkers call, rather than jobs in their own right.

| Script | What it does | Tests |
|--------|--------------|-------|
| [`list_changed_files`](../list_changed_files/) | Lists files changed between two commits. Used by most diff-based checkers. | |
| [`define_excluded`](../define_excluded/) | Emits the list of paths excluded from checks (third-party libs, etc.) in several formats. | [`define_excluded`](../tests/define_excluded.bats) |
| [`list_valid_components`](../list_valid_components/) | Produces the list of valid Moodle components. Needs a running DB/site. | [`list_valid_components`](../tests/list_valid_components.bats) |
| [`diff_extract_changes`](../diff_extract_changes/) | PHP helper: parses a unified diff and extracts changed line ranges (used to filter reports to modified lines). | [`diff_extract_changes`](../tests/diff_extract_changes.bats) |
| [`generate_component_ant_files`](../generate_component_ant_files/) | PHP helper: generates per-component Ant build files used by other CI steps. | |
| [`project_size_report`](../project_size_report/) | Reports code-size metrics for the project (uses PEAR/PHP tooling). | |
| [`phplib`](../phplib/) | Shared PHP CLI helper functions (`clilib.php`) reused by the PHP scripts. Not run directly. | |

Also covered by tests but not a script directory:
[`checkstyle_manipulations`](../tests/checkstyle_manipulations.bats) (checkstyle XML/XSLT
handling in `remote_branch_checker/xslt/`) and [`verifications`](../tests/verifications.bats)
(repo-wide hygiene: shebangs, file permissions, and that every tracked file has a known
extension — see [testing.md](testing.md)).

## Non-script directories

| Path | What |
|------|------|
| [`groovyscripts`](../groovyscripts/) | Groovy init scripts applied to the Jenkins server (add notification webhooks, remove post-build actions across all jobs). |
| [`jenkins_cli`](../jenkins_cli/) | Bundled `jenkins-cli.jar`, used by scripts that talk to the Jenkins CLI. |
| [`tracker_content_gadget`](../tracker_content_gadget/) | Static HTML gadgets embedded in the Moodle tracker (candidate/current issue pickers). |
| [`travis`](../travis/) | PHP helper to check a branch's Travis build status. Covered by [`travis-branch-checker`](../tests/travis-branch-checker.bats). |
| [`lang/en`](../lang/en/) | Moodle plugin language strings. |
| [`tests`](../tests/) | The bats suites, helpers and fixtures. See [testing.md](testing.md). |

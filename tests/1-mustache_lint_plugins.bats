#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_39_STABLE v3.9.1
}

@test "mustache_lint: Mustache files with Ionic3 syntax cause linting failure" {
    # Set up.
    git_apply_fixture 39-mustache_lint_plugins-templates.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result.
    assert_failure
    assert_output --partial "Running mustache lint from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "local/test/templates/linting_ok.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "local/test/templates/local/mobile/view.mustache - INFO: HTML Validation info"
    assert_output --partial "local/test/templates/local/mobile/view.mustache - WARNING: HTML Validation error"
    assert_output --partial "local/test/templates/mobile_view.mustache - WARNING: HTML Validation error"
    assert_output --partial "Mustache lint problems found"
}

@test "mustache_lint: Mustache files can be excluded from linting" {
    # Set up.
    git_apply_fixture 39-mustache_lint_plugins-templates.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    git_apply_fixture 39-mustache_lint_plugins-ignores.patch
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_success
    assert_output --partial "Running mustache lint from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "local/test/templates/linting_ok.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "local/test/templates/mobile_view.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "local/test/templates/local/mobile/view.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "local/test/templates/mobile_view.mustache - INFO: HTML validation skipped"
    assert_output --partial "local/test/templates/local/mobile/view.mustache - INFO: HTML validation skipped"
    assert_output --partial "No mustache problems found"
}

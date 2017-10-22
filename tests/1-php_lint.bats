#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.0
}

@test "php_lint: lib/moodlelib.php lint free" {
    # Set up.
    git_apply_fixture 31-php_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run php_lint/php_lint.sh

    # Assert result
    assert_success
    assert_output --partial "Running php syntax check from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/moodlelib.php - OK"
    assert_output --partial "No PHP syntax errors found"
}

@test "php_lint: lib/moodlelib.php lint error detected" {
    # Set up.
    git_apply_fixture 31-php_lint-bad.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run php_lint/php_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "Running php syntax check from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/moodlelib.php - ERROR:"
    assert_output --regexp "PHP syntax errors found."
}

@test "php_lint: shows the php version being used" {
    # Set up.
    git_apply_fixture 31-php_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run php_lint/php_lint.sh

    # Assert result
    assert_success
    assert_output --regexp "^Using PHP [0-9]+\.[0-9]+\.[0-9]+"
    assert_output --partial "Running php syntax check from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
}

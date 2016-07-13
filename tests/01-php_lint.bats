#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.0

    export extrapath=.
}

@test "php_lint: lib/moodlelib.php lint free" {
    cd $gitdir
    export GIT_PREVIOUS_COMMIT=$($gitcmd rev-parse HEAD)
    $gitcmd am $BATS_TEST_DIRNAME/fixtures/31-php_lint-ok.patch
    export GIT_COMMIT=$($gitcmd rev-parse HEAD)

    cd $BATS_TEST_DIRNAME/../php_lint/
    run ./php_lint.sh
    assert_success
    assert_output --partial "Running php syntax check from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/moodlelib.php - OK"
    assert_output --partial "No PHP syntax errors found"
}

@test "php_lint: lib/moodlelib.php lint error detected" {
    cd $gitdir
    export GIT_PREVIOUS_COMMIT=$($gitcmd rev-parse HEAD)
    $gitcmd am $BATS_TEST_DIRNAME/fixtures/31-php_lint-bad.patch
    export GIT_COMMIT=$($gitcmd rev-parse HEAD)

    # Run test
    cd $BATS_TEST_DIRNAME/../php_lint/
    run ./php_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "Running php syntax check from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/moodlelib.php - ERROR:"
    assert_output --regexp "PHP syntax errors found."
}

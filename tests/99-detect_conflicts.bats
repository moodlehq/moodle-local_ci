#!/usr/bin/env bats

load libs/shared_setup

statedir=$LOCAL_CI_TESTS_CACHEDIR/detect_conflicts/

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.1

    # Reset state between runs.
    if [ -d $statedir ]; then
        cp -R $statedir/. $WORKSPACE
    fi
}

teardown () {
    # Save state between individual runs
    mkdir -p $statedir
    cp -R $WORKSPACE/. $statedir
}

@test "detect_conflicts: first run OK" {
    # Ensure initial state is clean.
    clean_workspace_directory

    cd $BATS_TEST_DIRNAME/../detect_conflicts/
    # On first run, there are no results to compare to so should always
    # pass.
    run ./detect_conflicts.sh
    assert_success
    assert_output --partial "current count: 0"
    # The 'no previously recorded value' number is 999999
    assert_output --partial "previous count: 999999"
    assert_output --partial "best count: 999999"
    assert_output --partial "got best results ever, yay!"
}

@test "detect_conflicts: normal state OK" {
    cd $BATS_TEST_DIRNAME/../detect_conflicts/
    # On second run, should still pass with same results
    run ./detect_conflicts.sh
    assert_success
    assert_output --partial "current count: 0"
    assert_output --partial "previous count: 0"
    assert_output --partial "best count: 0"
    assert_output --partial "continue in best results ever"
}

@test "detect_conflicts: merge conflict FAIL" {
    # Lets introduce a merge conflict and ensure it fails
    cd $gitdir
    $gitcmd am $BATS_TEST_DIRNAME/fixtures/31-merge-conflict.patch

    cd $BATS_TEST_DIRNAME/../detect_conflicts/
    run ./detect_conflicts.sh
    assert_failure
    assert_output --partial "current count: 3"
    assert_output --partial "previous count: 0"
    assert_output --partial "best count: 0"
    assert_output --partial "worse results than previous counter"
}

@test "detect_conflicts: clean up state" {
    # Not a real test, just allows us to avoid storing state after
    # the rest of the test suite has run.
    clean_workspace_directory
}

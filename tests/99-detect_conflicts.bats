#!/usr/bin/env bats

load libs/shared_setup

statedir=$LOCAL_CI_TESTS_CACHEDIR/detect_conflicts/

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.1

    # Reset state between runs.
    if [ -d $statedir ]; then
        cp -R $statedir/. $WORKSPACE
    fi
    cd $BATS_TEST_DIRNAME/../detect_conflicts/
}

teardown () {
    # Save state between individual runs
    mkdir -p $statedir
    cp -R $WORKSPACE/. $statedir
}

@test "detect_conflicts: first run OK" {
    # Ensure initial state is clean.
    clean_workspace_directory

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
    # On second run, should still pass with same results
    run ./detect_conflicts.sh
    assert_success
    assert_output --partial "current count: 0"
    assert_output --partial "previous count: 0"
    assert_output --partial "best count: 0"
    assert_output --partial "continue in best results ever"
}

@test "detect_conflicts: merge conflict FAIL" {
    git_apply_fixture 31-merge-conflict.patch

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

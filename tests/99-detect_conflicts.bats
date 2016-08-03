#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.1
    # Restore workspace if not first test.
    first_test || restore_workspace
}

teardown () {
    # Store workspace if not last test.
    last_test || store_workspace
}

@test "detect_conflicts: first run OK" {
    # On first run, there are no results to compare to so should always
    # pass.
    ci_run detect_conflicts/detect_conflicts.sh
    assert_success
    assert_output --partial "current count: 0"
    # The 'no previously recorded value' number is 999999
    assert_output --partial "previous count: 999999"
    assert_output --partial "best count: 999999"
    assert_output --partial "got best results ever, yay!"
}

@test "detect_conflicts: normal state OK" {
    # On second run, should still pass with same results
    ci_run detect_conflicts/detect_conflicts.sh
    assert_success
    assert_output --partial "current count: 0"
    assert_output --partial "previous count: 0"
    assert_output --partial "best count: 0"
    assert_output --partial "continue in best results ever"
}

@test "detect_conflicts: failure reported when merge conflict detected" {
    git_apply_fixture 31-merge-conflict.patch

    ci_run detect_conflicts/detect_conflicts.sh
    assert_failure
    assert_output --partial "current count: 3"
    assert_output --partial "previous count: 0"
    assert_output --partial "best count: 0"
    assert_output --partial "worse results than previous counter"
}

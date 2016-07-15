#!/usr/bin/env bats

load libs/shared_setup


setup () {
    cd $BATS_TEST_DIRNAME/../travis/
}

@test "travis/check_branch_status.php: missing arguments" {
    run php check_branch_status.php
    assert_failure

    run php check_branch_status.php --repository=https://github.com/moodlehq/moodle-local_ci
    assert_failure

    run php check_branch_status.php --branch=master
    assert_failure
}

@test "travis/check_branch_status.php: branch OK" {

    run php check_branch_status.php --repository=https://github.com/moodlehq/moodle-local_ci --branch=master
    assert_success
    assert_output --regexp '^OK: Build status was passed, see '
}

@test "travis/check_branch_status.php: no travis setup" {
    # Use a moodlehq github repo which is unlikely to ever have travis integration.
    run php check_branch_status.php --repository=https://github.com/moodlehq/moodle-theme_afterburner --branch=master
    assert_success
    assert_output 'WARNING: Travis integration not setup. See https://docs.moodle.org/dev/Travis_Integration'
}

@test "travis/check_branch_status.php: not github repo" {
    # Travis only works with github repos, so skip non-github ones
    run php check_branch_status.php --repository=git://git.moodle.org/moodle.git --branch=master
    assert_success
    assert_output 'SKIP: Skipping checks. git://git.moodle.org/moodle.git Not a github repo.'
}

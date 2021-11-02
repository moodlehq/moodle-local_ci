#!/usr/bin/env bats

load libs/shared_setup


@test "travis/check_branch_status.php: missing arguments" {
    ci_run_php travis/check_branch_status.php
    assert_failure

    ci_run_php travis/check_branch_status.php --repository=https://github.com/moodlehq/moodle-local_ci
    assert_failure

    ci_run_php travis/check_branch_status.php --branch=master
    assert_failure
}

@test "travis/check_branch_status.php: OK, but using old travis-ci.org" {
    # A branch which Dan has had integrated and won't touch again (and is protected for this purpose). Using travis-ci.org
    ci_run_php travis/check_branch_status.php --repository=https://github.com/danpoltawski/moodle.git --branch=MDL-52127-master
    assert_success
    assert_line 'SKIP: travis-ci.com integration not setup. See https://docs.moodle.org/dev/Travis_integration'
    assert_line --partial 'SKIP: travis-ci.org integration working, but migration to travis-ci.com required.'
    assert_line --partial '. See https://docs.moodle.org/dev/Travis_integration'
    assert_line 'OK: Build status was passed, see https://travis-ci.org/danpoltawski/moodle/builds/137772508'
}

@test "travis/check_branch_status.php: branch OK, already using travis-ci.com" {
    # A branch which Eloy has had integrated and won't touch again (and is protected for this purpose). Using travis-ci.com
    ci_run_php travis/check_branch_status.php --repository=https://github.com/stronk7/moodle.git --branch=local_ci_test_travis_com
    assert_success
    assert_output 'OK: Build status was passed, see https://travis-ci.com/stronk7/moodle/builds/186304794'
}

@test "travis/check_branch_status.php: no travis setup" {
    # Use a moodlehq github repo which is unlikely to ever have travis integration.
    ci_run_php travis/check_branch_status.php --repository=https://github.com/moodlehq/moodle-theme_afterburner --branch=master
    assert_success
    assert_line 'SKIP: travis-ci.com integration not setup. See https://docs.moodle.org/dev/Travis_integration'
    assert_line 'SKIP: travis-ci.org integration not setup. See https://docs.moodle.org/dev/Travis_integration'
}

@test "travis/check_branch_status.php: not github repo" {
    # Travis only works with github repos, so skip non-github ones
    ci_run_php travis/check_branch_status.php --repository=git://git.moodle.org/moodle.git --branch=master
    assert_success
    assert_output 'SKIP: Skipping checks. git://git.moodle.org/moodle.git Not a github repo.'
}

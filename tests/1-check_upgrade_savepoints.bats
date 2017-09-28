#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.1
}

@test "check_upgrade_savepoints/check_upgrade_savepoints.sh: v3.1.1 savepoints verified" {
    ci_run check_upgrade_savepoints/check_upgrade_savepoints.sh
    assert_success
    run cat $WORKSPACE/check_upgrade_savepoints_MOODLE_31_STABLE.txt
    refute_output --partial 'ERROR:'
}

@test "check_upgrade_savepoints/check_upgrade_savepoints.sh: blank upgrade file" {
    git_apply_fixture check_upgrade_savepoints/blank_upgrade_file.patch

    ci_run check_upgrade_savepoints/check_upgrade_savepoints.sh
    assert_failure
    run grep ERROR $WORKSPACE/check_upgrade_savepoints_MOODLE_31_STABLE.txt
    assert_output --partial "ERROR: upgrade function not found"
}

@test "check_upgrade_savepoints/check_upgrade_savepoints.sh: repeated savepoint" {
    git_apply_fixture check_upgrade_savepoints/repeated_savepoint.patch

    ci_run check_upgrade_savepoints/check_upgrade_savepoints.sh
    assert_failure
    run grep WARN $WORKSPACE/check_upgrade_savepoints_MOODLE_31_STABLE.txt
    assert_output --partial "WARN: Detected less 'if' blocks (92) than 'savepoint' calls (93). Repeated savepoints?"
    assert_output --partial "WARN: version 2016051700.01 has more than one savepoint call"
}

@test "check_upgrade_savepoints/check_upgrade_savepoints.sh: no return statement" {
    git_apply_fixture check_upgrade_savepoints/no_return_statement.patch

    ci_run check_upgrade_savepoints/check_upgrade_savepoints.sh
    assert_failure
    run grep ERROR $WORKSPACE/check_upgrade_savepoints_MOODLE_31_STABLE.txt
    assert_output --partial "ERROR: 'return true;' not found"
}

@test "check_upgrade_savepoints/check_upgrade_savepoints.sh: multiple return statements" {
    git_apply_fixture check_upgrade_savepoints/multiple_return.patch

    ci_run check_upgrade_savepoints/check_upgrade_savepoints.sh
    assert_failure
    run grep ERROR $WORKSPACE/check_upgrade_savepoints_MOODLE_31_STABLE.txt
    assert_output --partial "ERROR: multiple 'return true;' detected"
}

@test "check_upgrade_savepoints/check_upgrade_savepoints.sh: if statement without savepoint" {
    git_apply_fixture check_upgrade_savepoints/if_without_savepoint.patch

    ci_run check_upgrade_savepoints/check_upgrade_savepoints.sh
    assert_failure
    run grep ERROR $WORKSPACE/check_upgrade_savepoints_MOODLE_31_STABLE.txt
    assert_output --partial "ERROR: Detected more 'if' blocks (92) than 'savepoint' calls (91)"
    assert_output --partial "ERROR: version 2016051300.00 is missing corresponding savepoint call"
}

@test "check_upgrade_savepoints/check_upgrade_savepoints.sh: wrong savepoint version" {
    git_apply_fixture check_upgrade_savepoints/wrong_savepoint_version.patch

    ci_run check_upgrade_savepoints/check_upgrade_savepoints.sh
    assert_failure
    run grep ERROR $WORKSPACE/check_upgrade_savepoints_MOODLE_31_STABLE.txt
    assert_output --partial "ERROR: version 2016012800 has wrong savepoint call with version 2016011800"
}

@test "check_upgrade_savepoints/check_upgrade_savepoints.sh: out of order savepoint steps" {
    git_apply_fixture check_upgrade_savepoints/out_of_order.patch

    ci_run check_upgrade_savepoints/check_upgrade_savepoints.sh
    assert_failure
    run grep ERROR $WORKSPACE/check_upgrade_savepoints_MOODLE_31_STABLE.txt
    assert_output --partial "ERROR: Wrong order in versions: 2014072400 and 2014051201"
}

@test "check_upgrade_savepoints/check_upgrade_savepoints.sh: savepoint higher than version.php" {
    git_apply_fixture check_upgrade_savepoints/too_high_savepoint.patch

    ci_run check_upgrade_savepoints/check_upgrade_savepoints.sh
    assert_failure
    run grep ERROR $WORKSPACE/check_upgrade_savepoints_MOODLE_31_STABLE.txt
    assert_output --partial "ERROR: version 2017022300 is higher than that defined in"
}

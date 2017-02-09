#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.0
}

@test "versions_check_set/versions_check_set.sh: 3.1.0 versions verified" {
    ci_run versions_check_set/versions_check_set.sh
    assert_success
    run cat $WORKSPACE/versions_check_set.txt
    refute_output --partial 'ERROR:'
}

@test "versions_check_set/versions_check_set.sh: main version missing" {
    git_apply_fixture versions_check_set/main_version_missing.patch

    ci_run versions_check_set/versions_check_set.sh
    assert_failure
    assert_output --partial "ERROR: Main version.php file is missing: \$branch = 'xx' line."
}

@test "versions_check_set/versions_check_set.sh: extra version digit" {
    git_apply_fixture versions_check_set/extra_version_digit.patch

    ci_run versions_check_set/versions_check_set.sh
    assert_failure
    assert_output --partial "ERROR: No correct version (10 digits + opt 2 more) found"
}

@test "versions_check_set/versions_check_set.sh: invalid date" {
    git_apply_fixture versions_check_set/invalid_date.patch

    ci_run versions_check_set/versions_check_set.sh
    assert_failure
    assert_output --partial "ERROR: No correct version first 8 digits date (date: invalid date"
}

@test "versions_check_set/versions_check_set.sh: invalid component" {
    git_apply_fixture versions_check_set/invalid_component.patch

    ci_run versions_check_set/versions_check_set.sh
    assert_failure
    assert_output --partial "ERROR: Component theme_morebeer not valid for that file"
}

@test "versions_check_set/versions_check_set.sh: no moodle internal" {
    git_apply_fixture versions_check_set/no_moodle_internal.patch

    ci_run versions_check_set/versions_check_set.sh
    assert_failure
    assert_output --partial "ERROR: File is missing: defined('MOODLE_INTERNAL') || die(); line."
}

@test "versions_check_set/versions_check_set.sh: no version defined" {
    git_apply_fixture versions_check_set/no_version_defined.patch

    ci_run versions_check_set/versions_check_set.sh
    assert_failure
    #TODO: fix the \ in the script output..
    assert_output --partial "ERROR: File is missing: \\\$plugin->version = 'xxxxxx' line."
}

@test "versions_check_set/versions_check_set.sh: short version number" {
    git_apply_fixture versions_check_set/short_version.patch

    ci_run versions_check_set/versions_check_set.sh
    assert_failure
    assert_output --partial "ERROR: No correct version (10 digits + opt 2 more) found"
}

@test "versions_check_set/versions_check_set.sh: version too far in the future" {
    git_apply_fixture versions_check_set/version_too_far_in_future.patch

    ci_run versions_check_set/versions_check_set.sh
    assert_failure
    run grep ERROR $WORKSPACE/versions_check_set.txt
    assert_output --partial "ERROR: No correct actual (<+7d) date found (2716-05-23)"
}

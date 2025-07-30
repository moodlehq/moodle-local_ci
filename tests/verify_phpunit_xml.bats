#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_311_STABLE v3.11.7
    # Restore workspace if not first test.
    first_test || restore_workspace
}

teardown () {
    # Store workspace if not last test.
    last_test || store_workspace
}

@test "verify_phpunit_xml: normal run without errors (old branch)" {
    ci_run verify_phpunit_xml/verify_phpunit_xml.sh

    assert_success
    assert_output --partial "OK: competency/tests will be executed"
    assert_output --partial "INFO: backup/util/ui/tests will be executed because the backup/util definition"
    assert_output --partial "INFO: Ignoring admin/tests, it does not contain any test unit file."
    refute_output --partial "WARNING"
    refute_output --partial "ERROR"
}

@test "verify_phpunit_xml: normal run without errors and warnings (main branch)" {
    create_git_branch main origin/main

    ci_run verify_phpunit_xml/verify_phpunit_xml.sh

    assert_success
    assert_output --partial "OK: public/competency/tests will be executed"
    assert_output --partial "INFO: public/backup/util/ui/tests will be executed because the public/backup/util definition"
    assert_output --partial "INFO: Ignoring public/theme/boost/scss/bootstrap/tests, it does not contain any test unit file."
    refute_output --partial "WARNING"
    refute_output --partial "ERROR"
}

@test "verify_phpunit_xml: test detected into not covered by suite directory" {
    git_apply_fixture verify_phpunit_xml/add_uncovered_test.patch

    ci_run verify_phpunit_xml/verify_phpunit_xml.sh

    assert_failure
    assert_output --partial "OK: competency/tests will be executed"
    assert_output --partial "INFO: backup/util/ui/tests will be executed because the backup/util definition"
    assert_output --partial "ERROR: admin/tests is not matched/covered by any definition in phpunit.xml !"
    refute_output --partial "WARNING"
    assert_output --partial "ERROR"
}

@test "verify_phpunit_xml: multiple classes in unit test file are warned by default" {
    git_apply_fixture verify_phpunit_xml/multiple_classes_in_file.patch

    ci_run verify_phpunit_xml/verify_phpunit_xml.sh

    assert_success
    assert_output --partial "OK: competency/tests will be executed"
    assert_output --partial "INFO: backup/util/ui/tests will be executed because the backup/util definition"
    assert_output --partial "INFO: Ignoring admin/tests, it does not contain any test unit file."
    assert_output --partial "WARNING: mod/glossary/tests/lib_test.php has incorrect (2) number of unit test classes."
    refute_output --partial "ERROR"
}

@test "verify_phpunit_xml: multiple classes in unit test file emit error if configured" {
    git_apply_fixture verify_phpunit_xml/multiple_classes_in_file.patch

    export multipleclassiserror=yes # Let's force multiple classes to lead to error.

    ci_run verify_phpunit_xml/verify_phpunit_xml.sh

    assert_failure
    assert_output --partial "OK: competency/tests will be executed"
    assert_output --partial "INFO: backup/util/ui/tests will be executed because the backup/util definition"
    assert_output --partial "INFO: Ignoring admin/tests, it does not contain any test unit file."
    assert_output --partial "ERROR: mod/glossary/tests/lib_test.php has incorrect (2) number of unit test classes."
    assert_output --partial "ERROR"
}

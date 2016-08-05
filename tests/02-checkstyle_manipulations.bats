#!/usr/bin/env bats

load libs/shared_setup

# Helper to assert checkstyle converts
# usage: assert_checkstyle phpscript fixturefilename expectedfilename
assert_checkstyle() {
    phpscript=$1
    fixture=$BATS_TEST_DIRNAME/fixtures/checkstyle/$2
    expected=$BATS_TEST_DIRNAME/fixtures/checkstyle/$3

    xmlfile=$BATS_TMPDIR/out.xml

    ci_run_php "$phpscript < $fixture > $xmlfile"
    assert_success
    assert_files_same $expected $xmlfile
    rm $xmlfile
}

@test "check_upgrade_savepoints/savepoints2checkstyle.php" {
    assert_checkstyle check_upgrade_savepoints/savepoints2checkstyle.php savepoints.txt savepoints.xml
}

@test "verify_commit_messages/commits2checkstyle.php" {
    assert_checkstyle verify_commit_messages/commits2checkstyle.php commits.txt commits.xml
}

@test "remote_branch_checker/checkstyle_converter.php: phplint" {
    assert_checkstyle 'remote_branch_checker/checkstyle_converter.php --format=phplint' phplint.txt phplint.xml
}

@test "remote_branch_checker/checkstyle_converter.php: thirdparty" {
    assert_checkstyle 'remote_branch_checker/checkstyle_converter.php --format=thirdparty' thirdparty.txt thirdparty.xml
}

@test "remote_branch_checker/checkstyle_converter.php: grunt" {
    assert_checkstyle 'remote_branch_checker/checkstyle_converter.php --format=gruntdiff' grunt.txt grunt.xml
}

@test "remote_branch_checker/checkstyle_converter.php: shifter" {
    assert_checkstyle 'remote_branch_checker/checkstyle_converter.php --format=shifter' grunt-errors.txt shifter.xml
}

@test "remote_branch_checker/checkstyle_converter.php: travis" {
    assert_checkstyle 'remote_branch_checker/checkstyle_converter.php --format=travis' travis.txt travis.xml
    assert_checkstyle 'remote_branch_checker/checkstyle_converter.php --format=travis' travis-error.txt travis-error.xml
}

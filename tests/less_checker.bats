#!/usr/bin/env bats

load libs/shared_setup


setup () {
    create_git_branch MOODLE_27_STABLE v2.7.14

    export extrapath=.
    # Setup recess base.
    export recessbase=$LOCAL_CI_TESTS_CACHEDIR/recess
    mkdir -p $recessbase
}

@test "less_checker: normal" {
    cd $BATS_TEST_DIRNAME/../less_checker/
    run ./less_checker.sh
    assert_success
    assert_output --partial "OK: All .less files are perfectly compiled and matching git contents"
}

@test "less_checker: uncommitted less change" {
    cd $gitdir
    $gitcmd am $BATS_TEST_DIRNAME/fixtures/27-less-unbuilt.patch
    cd $BATS_TEST_DIRNAME/../less_checker/
    run ./less_checker.sh
    assert_failure
    assert_output --partial "ERROR: Some .less files are not matching git contents. Changes detected:"
    assert_output --partial "theme/bootstrapbase/style/moodle.css"
}

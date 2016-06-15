#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_27_STABLE v2.7.14

    export extrapath=.
    # setup shifter base.
    export shifterbase=$LOCAL_CI_TESTS_CACHEDIR/shifter
    mkdir -p $shifterbase
}

@test "shifter_walk: normal" {
    cd $BATS_TEST_DIRNAME/../shifter_walk/
    run ./shifter_walk.sh
    assert_success
    assert_output --partial "OK: All modules are perfectly shiftered"
}

@test "shifter_walk: Uncommitted .js change" {
    cd $gitdir
    $gitcmd am $BATS_TEST_DIRNAME/fixtures/27-shifter-unbuildjs.patch
    cd $BATS_TEST_DIRNAME/../shifter_walk/
    run ./shifter_walk.sh
    assert_failure
    assert_output --partial "ERROR: Some modules are not properly shiftered. Changes detected:"
    assert_output --partial "lib/editor/atto/yui/build/moodle-editor_atto-editor/moodle-editor_atto-editor.js"
}

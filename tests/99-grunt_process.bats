#!/usr/bin/env bats

load libs/shared_setup


setup () {
    create_git_branch MOODLE_31_STABLE v3.1.0

    export extrapath=.
    cd $BATS_TEST_DIRNAME/../grunt_process/
}

@test "grunt_process: normal" {
    run ./grunt_process.sh
    assert_success
    assert_output --partial "Done, without errors."
    assert_output --partial "OK: All modules are perfectly processed by grunt"
}

@test "grunt_process: Uncommited .less change" {
    # Create less change
    git_apply_fixture 31-grunt-less-unbuilt.patch

    # Run test
    run ./grunt_process.sh

    # Assert result
    assert_failure
    assert_output --partial "Done, without errors." # Grunt shouldn't have an issue here.
    assert_output --partial "ERROR: Some modules are not properly processed by grunt. Changes detected:"
    assert_output --regexp "GRUNT-CHANGE: (.*)/theme/bootstrapbase/style/moodle.css"
}

@test "grunt_process: Uncommited .js change" {
    # Create js change.
    git_apply_fixture 31-grunt-js-unbuilt.patch

    # Run test
    run ./grunt_process.sh

    # Assert result
    assert_failure
    assert_output --partial "Done, without errors." # Grunt shouldn't have an issue here.
    assert_output --partial "ERROR: Some modules are not properly processed by grunt. Changes detected:"
    assert_output --regexp "GRUNT-CHANGE: (.*)/lib/amd/build/url.min.js"
}

@test "grunt_process: Uncommited ignorefiles change" {
    # When a third party library is added, developers need to commit
    # ignorefiles change since 3.2.

    # Testing on in-dev 3.2dev
    create_git_branch 32-dev 5a1728df39116fc701cc907e85a638aa7674f416
    git_apply_fixture 32-thirdparty-lib-added.patch

    # Run test
    run ./grunt_process.sh

    # Assert result
    assert_failure
    assert_output --partial "ERROR: Some modules are not properly processed by grunt. Changes detected:"
    assert_output --regexp "GRUNT-CHANGE: (.*)/.eslintignore"
}


#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.0

    export extrapath=.
}

@test "thirdparty_check: thirdpartyfile modified OK" {
    cd $gitdir
    export initialcommit=$($gitcmd rev-parse HEAD)
    $gitcmd am $BATS_TEST_DIRNAME/fixtures/31-thirdparty-ok.patch
    export finalcommit=$($gitcmd rev-parse HEAD)

    cd $BATS_TEST_DIRNAME/../thirdparty_check/
    run ./thirdparty_check.sh
    assert_success
    assert_output --partial "INFO: Checking for third party modifications from $initialcommit to $finalcommit"
    assert_output --partial "INFO: Detected third party modification in lib/amd/src/mustache.js"
    assert_output --partial "INFO: OK lib/thirdpartylibs.xml modified"
    refute_output --partial "WARN:"
}

@test "thirdparty_check: thirdpartyfile modified without update" {
    cd $gitdir
    export initialcommit=$($gitcmd rev-parse HEAD)
    $gitcmd am $BATS_TEST_DIRNAME/fixtures/31-thirdparty-error.patch
    export finalcommit=$($gitcmd rev-parse HEAD)

    cd $BATS_TEST_DIRNAME/../thirdparty_check/
    run ./thirdparty_check.sh
    assert_success # TODO, this should be fixed!
    assert_output --partial "INFO: Checking for third party modifications from $initialcommit to $finalcommit"
    assert_output --partial "INFO: Detected third party modification in lib/amd/src/mustache.js"
    assert_output --partial "WARN: modification to third party library (lib/amd/src/mustache.js) without update to lib/thirdpartylibs.xml or lib/amd/src/readme_moodle.txt"
}

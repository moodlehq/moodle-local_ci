#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.0

    export extrapath=.
}

@test "thirdparty_check: thirdpartyfile modified OK" {
    git_apply_fixture 31-thirdparty-ok.patch
    export initialcommit=$FIXTURE_HASH_BEFORE
    export finalcommit=$FIXTURE_HASH_AFTER

    ci_run thirdparty_check/thirdparty_check.sh
    assert_success
    assert_output --partial "INFO: Checking for third party modifications from $initialcommit to $finalcommit"
    assert_output --partial "INFO: Detected third party modification in lib/amd/src/mustache.js"
    assert_output --partial "INFO: OK lib/thirdpartylibs.xml modified"
    refute_output --partial "WARN:"
}

@test "thirdparty_check: thirdpartyfile modified without update" {
    git_apply_fixture 31-thirdparty-error.patch
    export initialcommit=$FIXTURE_HASH_BEFORE
    export finalcommit=$FIXTURE_HASH_AFTER

    ci_run thirdparty_check/thirdparty_check.sh
    assert_success # TODO, this should be fixed!
    assert_output --partial "INFO: Checking for third party modifications from $initialcommit to $finalcommit"
    assert_output --partial "INFO: Detected third party modification in lib/amd/src/mustache.js"
    assert_output --partial "WARN: modification to third party library (lib/amd/src/mustache.js) without update to lib/thirdpartylibs.xml or lib/amd/src/readme_moodle.txt"
}

@test "thirdparty_check: lib/requirejs.php edgecase" {
    # Test case for lib/requirejs.php which isn't in folder lib/requirejs/
    git_apply_fixture 31-thirdparty-edgecase.patch
    export initialcommit=$FIXTURE_HASH_BEFORE
    export finalcommit=$FIXTURE_HASH_AFTER

    ci_run thirdparty_check/thirdparty_check.sh
    assert_success
    refute_output --partial "WARN:"
    assert_output "INFO: Checking for third party modifications from $initialcommit to $finalcommit"
}

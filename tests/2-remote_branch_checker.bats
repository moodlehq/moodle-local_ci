#!/usr/bin/env bats

load libs/shared_setup

# TODO: we will get rid of these depencies soon.
prepare_prechecker_npmbins () {
    npmglobals=$LOCAL_CI_TESTS_CACHEDIR/prechecker_npmglobals

    mkdir -p $npmglobals
    cd $npmglobals

    export csslintcmd=$npmglobals/node_modules/.bin/csslint
    if [[ ! -f $csslintcmd ]]; then
        $npmcmd --silent install csslint
    fi

    export jshintcmd=$npmglobals/node_modules/.bin/jshint
    if [[ ! -f $jshintcmd ]]; then
        $npmcmd --silent install jshint
    fi
    cd $OLDPWD
}

setup () {
    prepare_prechecker_npmbins

    create_git_branch MOODLE_31_STABLE v3.1.1
    export WORKSPACE=$gitdir
    export phpcsstandard=$LOCAL_CI_TESTS_PHPCS_DIR
}

# Assert prechecker results
# usage: assert_prechecker branch issue commit summary
assert_prechecker () {
    export branch=$1
    export issue=$2
    export resettocommit=$3

    smurfxmlfixture=$BATS_TEST_DIRNAME/fixtures/remote_branch_checker/$branch.xml

    if [ ! -f $smurfxmlfixture ]; then
        fail "A smurf.xml fixture must be provided at fixtures/remote_branch_checker/$branch.xml"
    fi

    export integrateto=master
    export rebaseerror=9999
    export remote=https://git.in.moodle.com/integration/prechecker.git
    export extrapath=.

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_success
    assert_files_same $smurfxmlfixture $WORKSPACE/work/smurf.xml
}

@test "remote_branch_checker/remote_branch_checker.sh: old branch failing" {
    # An extremely old branch running jshint..
    assert_prechecker local_ci_fixture_oldbranch MDLSITE-3899 b3f5865eabbbdd439ac7f2ec763046f2ac7f0b37
}

@test "remote_branch_checker/remote_branch_checker.sh: all possible checks failing" {
    # from https://integration.moodle.org/job/Precheck%20remote%20branch/26024/
    assert_prechecker MDL-53136-master-dc60e4f MDL-53136 d1a3ea62ef79f2d4d997e329a647535340ef15db
}

@test "remote_branch_checker/remote_branch_checker.sh: all checks passing" {
    # from https://integration.moodle.org/job/Precheck%20remote%20branch/25996/
    assert_prechecker MDL-53572-master-8ce58c9 MDL-53572 d1a3ea62ef79f2d4d997e329a647535340ef15db
}

@test "remote_branch_checker/remote_branch_checker.sh: stylelint checks" {
    assert_prechecker prechecker-fixture-stylelint MDL-12345 7752762674c1211e00c5d24045c065c41f5bc662
}

@test "remote_branch_checker/remote_branch_checker.sh: all results reported despite no php/js/css files" {
    # Ensure we always report each section, even if there are no php/css/js files to check
    assert_prechecker fixture-non-code-update MDL-12345 6f302b17b97078059d4f02d747abf5822a064e87
}

@test "remote_branch_checker/remote_branch_checker.sh: thirdparty css modification" {
    # Ensure stylelint doesn't complain about the third party css, but thirdpart does
    # TODO: thirdparty check bug with reporting same file twice..
    assert_prechecker fixture-thirdparty-css MDL-12345 6f302b17b97078059d4f02d747abf5822a064e87
}

@test "remote_branch_checker/remote_branch_checker.sh: bad amos script" {
    assert_prechecker fixture-bad-amos-commands MDL-12345 6f302b17b97078059d4f02d747abf5822a064e87
}

@test "remote_branch_checker/remote_branch_checker.sh: good amos commands" {
    assert_prechecker fixture-good-amos-commit MDL-12345 6f302b17b97078059d4f02d747abf5822a064e87
}

@test "remote_branch_checker/remote_branch_checker.sh: mustache lint" {
    assert_prechecker fixture-mustache-lint MDL-12345 d9520bc04e4d47d8dedfbe6b07cbbe0cb14c7fcf
}

@test "remote_branch_checker/remote_branch_checker.sh: mustache lint eslint problem" {
    assert_prechecker fixture-mustache-lint-js MDL-12345 cad8adccc796f40ab11b1236cd637e9b987c17c8
}

@test "remote_branch_checker/remote_branch_checker.sh: grunt build failed" {
    assert_prechecker fixture-grunt-build-failed MDL-12345 cd4a6b8b0bca159d3abb1468794ed5a074c5b701
}

@test "remote_branch_checker/remote_branch_checker.sh: remote which doesnt exist" {
    export branch="a-branch-which-will-never-exist"
    export issue="MDL-12345"
    export integrateto=master
    export rebaseerror=9999
    export remote=https://git.in.moodle.com/integration/prechecker.git
    export extrapath=.

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    assert_output --partial "Unable to fetch information from a-branch-which-will-never-exist branch"
}

@test "remote_branch_checker/remote_branch_checker.sh: github branch rewritten" {
    # With this test, we are only interested in checking the github url rewriting..
    export remote=git://github.com/danpoltawski/moodle.git
    export branch="https://github.com/danpoltawski/moodle/tree/a-branch-which-doesnt-exist"
    export issue="MDL-12345"
    export integrateto=master
    export rebaseerror=9999
    export extrapath=.

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    # The main part of the test:
    assert_output --partial "Warn: the branch https://github.com/danpoltawski/moodle/tree/a-branch-which-doesnt-exist should not be specified as a github url"
    # This is just how it will fail because we don't want to run the entire testsuite..
    assert_output --partial "Error: Unable to fetch information from a-branch-which-doesnt-exist branch at git://github.com/danpoltawski/moodle.git"
}
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
    shortsummary=$4

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
    assert_output --partial "SMURFRESULT: $shortsummary"

    assert_files_same $smurfxmlfixture $WORKSPACE/work/smurf.xml
}

@test "remote_branch_checker/remote_branch_checker.sh: old branch failing" {
    # An extremely old branch running jshint..
    assert_prechecker local_ci_fixture_oldbranch MDLSITE-3899 b3f5865eabbbdd439ac7f2ec763046f2ac7f0b37 \
    "smurf,error,3,6:phplint,success,0,0;phpcs,success,0,0;js,warning,0,6;css,success,0,0;phpdoc,success,0,0;commit,error,3,0;savepoint,success,0,0;thirdparty,success,0,0;grunt,success,0,0;shifter,success,0,0;travis,success,0,0"
}

@test "remote_branch_checker/remote_branch_checker.sh: all possible checks failing" {
    # from https://integration.moodle.org/job/Precheck%20remote%20branch/26024/
    assert_prechecker MDL-53136-master-dc60e4f MDL-53136 d1a3ea62ef79f2d4d997e329a647535340ef15db \
    "smurf,error,14,6:phplint,error,1,0;phpcs,error,2,2;js,error,2,1;css,error,1,1;phpdoc,success,0,0;commit,error,1,1;savepoint,error,2,0;thirdparty,warning,0,1;grunt,error,5,0;shifter,success,0,0;travis,success,0,0"
}

@test "remote_branch_checker/remote_branch_checker.sh: all checks passing" {
    # from https://integration.moodle.org/job/Precheck%20remote%20branch/25996/
    assert_prechecker MDL-53572-master-8ce58c9 MDL-53572 d1a3ea62ef79f2d4d997e329a647535340ef15db \
    "smurf,success,0,0:phplint,success,0,0;phpcs,success,0,0;js,success,0,0;css,success,0,0;phpdoc,success,0,0;commit,success,0,0;savepoint,success,0,0;thirdparty,success,0,0;grunt,success,0,0;shifter,success,0,0;travis,success,0,0"
}

@test "remote_branch_checker/remote_branch_checker.sh: stylelint checks" {
    assert_prechecker prechecker-fixture-stylelint MDL-12345 7752762674c1211e00c5d24045c065c41f5bc662 \
    "smurf,error,3,1:phplint,success,0,0;phpcs,success,0,0;js,success,0,0;css,error,3,1;phpdoc,success,0,0;commit,success,0,0;savepoint,success,0,0;thirdparty,success,0,0;grunt,success,0,0;shifter,success,0,0;travis,success,0,0"
}

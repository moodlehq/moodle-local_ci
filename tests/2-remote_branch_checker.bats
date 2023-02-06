#!/usr/bin/env bats

load libs/shared_setup

setup () {
    # This was the first .0 version coming with .nvmrc file, so it's the minimum supported by local_ci.
    create_git_branch MOODLE_38_STABLE v3.8.0 # Must be always a .0 version coz we precheck it in master.
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

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_success
    assert_files_same $smurfxmlfixture $WORKSPACE/work/smurf.xml
}

@test "remote_branch_checker/remote_branch_checker.sh: old branch (38_STABLE) failing" {
    # An extremely old branch. MOODLE_38_STABLE (with node v14) is the oldest we support.
    # (note MOODLE_35_STABLE and up also is supported but not v3.5.0, v3.6.0...  support came later and
    # we need to use always .0 versions in the tests as base, so 3.8.0 is the very first .0).
    assert_prechecker local_ci_fixture_oldbranch_38 MDLSITE-3899 v3.8.0
}

@test "remote_branch_checker/remote_branch_checker.sh: all possible checks failing" {
    # A branch with a good number of errors
    assert_prechecker local_ci_fixture_manyproblems_38 MDL-53136 v3.8.0
}

@test "remote_branch_checker/remote_branch_checker.sh: all checks passing" {
    assert_prechecker local_ci_fixture_all_passing MDL-53572 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: stylelint checks" {
    assert_prechecker local_ci_fixture_stylelint MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: all results reported despite no php/js/css files" {
    # Ensure we always report each section, even if there are no php/css/js files to check
    assert_prechecker local_ci_fixture_noncode_update MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: thirdparty css modification" {
    # Ensure stylelint doesn't complain about the third party css, but thirdparty does
    # TODO: thirdparty check bug with reporting same file twice..
    assert_prechecker local_ci_fixture_thirdparty_css MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: upgrade external backup" {
    assert_prechecker local_ci_fixture_upgrade_external_backup MDL-12345 v4.0.0
}

@test "remote_branch_checker/remote_branch_checker.sh: upgrade external backup skipped for plugins" {
    # With branches named PLUGIN-xxxx, the upgrade_external_backup check will be skipped,
    # no matter the verified branch has 3 warnings when running for non plugins.
    assert_prechecker local_ci_fixture_upgrade_external_backup_skipped_for_plugins PLUGIN-12345 v4.0.0
}

@test "remote_branch_checker/remote_branch_checker.sh: phpcs aware of all components" {
    assert_prechecker local_ci_fixture_phpcs_aware_components MDL-12345 c69c33b14d9fb83ca22bde558169e36b5e1047cf
}

@test "remote_branch_checker/remote_branch_checker.sh: bad amos script" {
    assert_prechecker local_ci_fixture_bad_amos_command MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: good amos commands" {
    assert_prechecker local_ci_fixture_good_amos_commit MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: mustache lint" {
    assert_prechecker local_ci_fixture_mustache_lint MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: mustache lint eslint problem" {
    assert_prechecker local_ci_fixture_mustache_lint_js MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: gherkin lint" {
    assert_prechecker local_ci_fixture_gherkin_lint MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: grunt build failed" {
    assert_prechecker local_ci_fixture_grunt_build_failed MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: remote which doesnt exist" {
    export branch="a-branch-which-will-never-exist"
    export issue="MDL-12345"
    export integrateto=master
    export rebaseerror=9999
    export remote=https://git.in.moodle.com/integration/prechecker.git

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    assert_output --partial "Unable to fetch information from a-branch-which-will-never-exist branch"
}

@test "remote_branch_checker/remote_branch_checker.sh: github branch rewritten" {
    # With this test, we are only interested in checking the github url rewriting..
    export remote=https://github.com/danpoltawski/moodle.git
    export branch="https://github.com/danpoltawski/moodle/tree/a-branch-which-doesnt-exist"
    export issue="MDL-12345"
    export integrateto=master
    export rebaseerror=9999

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    # The main part of the test:
    assert_output --partial "Warn: the branch https://github.com/danpoltawski/moodle/tree/a-branch-which-doesnt-exist should not be specified as a github url"
    # This is just how it will fail because we don't want to run the entire testsuite..
    assert_output --partial "Error: Unable to fetch information from a-branch-which-doesnt-exist branch at https://github.com/danpoltawski/moodle.git"
}

@test "remote_branch_checker/remote_branch_checker.sh: github remote rewritten" {
    # With this test, we are only interested in checking the github url rewriting for git://github.com URLs.
    export remote=git://github.com/moodle/moodle.git
    export branch="a-branch-which-doesnt-exist"
    export issue="MDL-12345"
    export integrateto=master
    export rebaseerror=9999

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    # The main part of the test:
    assert_output --partial "Warn: the remote 'git://github.com/moodle/moodle.git' is using an unauthenticated github url which is no longer supported. Converting to 'https://github.com/moodle/moodle.git'"
    # This is just how it will fail because we don't want to run the entire testsuite..
    assert_output --partial "Error: Unable to fetch information from a-branch-which-doesnt-exist branch at https://github.com/moodle/moodle.git"
}

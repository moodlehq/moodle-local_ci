#!/usr/bin/env bats

load libs/shared_setup

setup_file() {
    # Build the former prechecker branches from tracked patches and the supplied Moodle history.
    export fixtureremote="$BATS_FILE_TMPDIR/remote.git"
    git clone --quiet --shared --bare "$gitdir" "$fixtureremote"
    git -C "$fixtureremote" branch --force main v3.9.0
    git -C "$fixtureremote" symbolic-ref HEAD refs/heads/main

    export LOCAL_CI_TESTS_GITDIR="$BATS_FILE_TMPDIR/checkout"
    export gitdir="$LOCAL_CI_TESTS_GITDIR"
    git clone --quiet --shared --no-checkout "$fixtureremote" "$gitdir"
    git -C "$gitdir" config user.name "Local CI"
    git -C "$gitdir" config user.email "local_ci@moodle.com"
    git -C "$gitdir" remote add integration "$fixtureremote"

    create_prechecker_fixture oldbranch_38 v3.8.0
    create_prechecker_fixture manyproblems_38 v3.8.0
    create_prechecker_fixture all_passing v3.9.0
    create_prechecker_fixture stylelint v3.9.0
    create_prechecker_fixture noncode_update v3.9.0
    create_prechecker_fixture thirdparty_css v3.9.0
    create_prechecker_fixture upgrade_external_backup v4.0.0
    git -C "$fixtureremote" branch local_ci_fixture_upgrade_external_backup_skipped_for_plugins \
        local_ci_fixture_upgrade_external_backup
    create_prechecker_fixture phpcs_aware_components c69c33b14d9fb83ca22bde558169e36b5e1047cf
    create_prechecker_fixture bad_amos_command v3.9.0
    create_prechecker_fixture good_amos_commit v3.9.0
    create_prechecker_fixture mustache_lint v3.9.0
    create_prechecker_fixture mustache_lint_js v3.9.0
    create_prechecker_fixture gherkin_lint v3.9.0
    create_prechecker_fixture grunt_build_failed v3.9.0
    create_prechecker_fixture upgrade_txt_for_404 v4.4.0
    create_prechecker_fixture upgrade_txt_for_405 d32844ce296
    create_prechecker_fixture merge_conflict v4.4.0
    create_prechecker_fixture merge_target v4.4.0
    git -C "$fixtureremote" branch --force MOODLE_404_STABLE local_ci_fixture_merge_target

    # Exercise public URL handling and report links without contacting a host.
    export fixtureurl=https://github.com/local-ci/fixtures.git
    git -C "$gitdir" config --add url."$fixtureremote".insteadOf "$fixtureurl"
    git -C "$gitdir" config --add url."$fixtureremote".insteadOf https://github.com/danpoltawski/moodle.git
    git -C "$gitdir" config --add url."$fixtureremote".insteadOf https://github.com/moodle/moodle.git
    git -C "$gitdir" config --add url."$fixtureremote".insteadOf https://github.com/moodle/integration.git
    # Reject any unmapped network URL.
    export GIT_ALLOW_PROTOCOL=file
}

create_prechecker_fixture() {
    local name="local_ci_fixture_$1"
    git -C "$gitdir" checkout --quiet -B "$name" "$2"
    git -C "$gitdir" am --quiet "$BATS_TEST_DIRNAME/fixtures/remote_branch_checker/$name.patch"
    git -C "$fixtureremote" fetch --quiet "$gitdir" "$name:refs/heads/$name"
}

setup () {
    # This was the first .0 version coming with .nvmrc file, so it's the minimum supported by local_ci.
    create_git_branch MOODLE_38_STABLE v3.8.0 # Must be always a .0 version coz we precheck it in main.
    export WORKSPACE=$gitdir
    export phpcsstandard=$LOCAL_CI_TESTS_PHPCS_DIR
    git -C "$gitdir" remote set-url integration "$fixtureremote"
}

teardown () {
    # Some test may end with the repo in rebase/merging conflicts status. Let's reset/abort that always.
    cd ${gitdir} && ${gitcmd} reset --hard HEAD
}

# Assert prechecker results
# usage: assert_prechecker branch issue commit summary
# Performs a prechecker run and asserts the results against a collection of
# regular expressions (one by line) or against a complete XML fixture file.
assert_prechecker () {
    export branch=$1
    export issue=$2
    export resettocommit=$3

    smurfxmlfixture=$BATS_TEST_DIRNAME/fixtures/remote_branch_checker/$branch.xml
    smurfregexfixture=$BATS_TEST_DIRNAME/fixtures/remote_branch_checker/$branch.regex

    if [ ! -r $smurfregexfixture ]; then
        if [ ! -r $smurfxmlfixture ]; then
            fail "A .regex with matches or a complete .xml must be provided at fixtures/remote_branch_checker/$branch.[regex|xml]"
        fi
    fi

    if [ -r $smurfregexfixture ] && [ -r $smurfxmlfixture ]; then
        fail "Only one of .regex or .xml must be provided at fixtures/remote_branch_checker/$branch.[regex|xml]"
    fi

    export integrateto=main
    export rebaseerror=9999
    export remote="$fixtureurl"

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_success
    if [ -r $smurfregexfixture ]; then
        # Fixture commit hashes change when the patches are applied.
        local fixturehash
        fixturehash=$(git -C "$fixtureremote" rev-parse "$branch")
        sed "s/@FIXTURE_HASH@/$fixturehash/g" "$smurfregexfixture" > "$BATS_TEST_TMPDIR/smurf.regex"
        assert_file_matches "$BATS_TEST_TMPDIR/smurf.regex" "$WORKSPACE/work/smurf.xml"
    else
        assert_files_same $smurfxmlfixture $WORKSPACE/work/smurf.xml
    fi
}

@test "remote_branch_checker/remote_branch_checker.sh: old branch (38_STABLE) failing" {
    # An extremely old branch. MOODLE_38_STABLE is the oldest we support.
    # (note MOODLE_35_STABLE and up also is supported but not v3.5.0, v3.6.0...  support came later and
    # we need to use always .0 versions in the tests as base, so 3.8.0 is the very first .0).
    assert_prechecker local_ci_fixture_oldbranch_38 MDLSITE-3899 v3.8.0
}

@test "remote_branch_checker/remote_branch_checker.sh: all possible checks failing" {
    # A branch with a good number of errors
    assert_prechecker local_ci_fixture_manyproblems_38 MDL-53136 v3.8.0
}

@test "remote_branch_checker/remote_branch_checker.sh: all checks passing" {
    export rebasewarn=999999 # Dont' warn about rebase ever.
    export rebaseerror=999999 # Don't fail about rebase ever.
    assert_prechecker local_ci_fixture_all_passing MDL-53572 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: stylelint checks" {
    assert_prechecker local_ci_fixture_stylelint MDL-12345 v3.9.0
}

@test "remote_branch_checker/remote_branch_checker.sh: all results reported despite no php/js/css files" {
    export rebasewarn=999999 # Dont' warn about rebase ever.
    export rebaseerror=999999 # Don't fail about rebase ever.
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
    export rebasewarn=999999 # Dont' warn about rebase ever.
    export rebaseerror=999999 # Don't fail about rebase ever.
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
    export integrateto=main
    export rebaseerror=9999
    export remote="$fixtureremote"

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    assert_output --partial "Unable to fetch information from a-branch-which-will-never-exist branch"
    refute_output --partial "integration remote not found"
    run git -C "$gitdir" config remote.integration.url
    assert_success
    assert_output "$fixtureremote"
}

@test "remote_branch_checker/remote_branch_checker.sh: github branch rewritten" {
    # With this test, we are only interested in checking the github url rewriting..
    export remote=https://github.com/danpoltawski/moodle.git
    export branch="https://github.com/danpoltawski/moodle/tree/a-branch-which-doesnt-exist"
    export issue="MDL-12345"
    export integrateto=main
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
    export integrateto=main
    export rebaseerror=9999

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    # The main part of the test:
    assert_output --partial "Warn: the remote 'git://github.com/moodle/moodle.git' is using an unauthenticated github url which is no longer supported. Converting to 'https://github.com/moodle/moodle.git'"
    # This is just how it will fail because we don't want to run the entire testsuite..
    assert_output --partial "Error: Unable to fetch information from a-branch-which-doesnt-exist branch at https://github.com/moodle/moodle.git"
}

@test "remote_branch_checker/remote_branch_checker.sh: detect changes to upgrade.txt and UPGRADING.md (<4.5)" {
    export rebasewarn=999999 # Dont' warn about rebase ever.
    export rebaseerror=999999 # Don't fail about rebase ever.
    assert_prechecker local_ci_fixture_upgrade_txt_for_404 MDL-12345 v4.4.0
}

@test "remote_branch_checker/remote_branch_checker.sh: detect changes to upgrade.txt and UPGRADING.md (>=4.5)" {
    export rebasewarn=999999 # Dont' warn about rebase ever.
    export rebaseerror=999999 # Don't fail about rebase ever.
    # Use 4.5dev (d32844ce296), May 2024, as the base commit.
    assert_prechecker local_ci_fixture_upgrade_txt_for_405 MDL-12345 d32844ce296
}

@test "remote_branch_checker/remote_branch_checker.sh: verify that merge conflicts are properly reported" {
    export rebasewarn=999999 # Dont' warn about rebase ever.
    export rebaseerror=999999 # Don't fail about rebase ever.
    export branch="local_ci_fixture_merge_conflict"
    export issue="MDL-12345"
    export integrateto=MOODLE_404_STABLE
    export remote="$fixtureremote"

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    assert_output --partial "Info: Attempting merge to origin/MOODLE_404_STABLE"
    assert_output --partial "Merge conflict in admin/environment.xml"
    assert_output --partial "Merge conflict in admin/roles/tests/preset_test.php"
    assert_output --partial "Merge conflict in admin/tests/behat/browse_users.feature"
    assert_output --partial "Error: The local_ci_fixture_merge_conflict branch"
    assert_output --partial "does not apply clean to origin/MOODLE_404_STABLE"
    assert_output --partial "Error: Merge conflict(s) in file(s):"
    assert_output --partial "Error: admin/environment.xml"
    assert_output --partial "Error: admin/roles/tests/preset_test.php"
    assert_output --partial "Error: admin/tests/behat/browse_users.feature"
}

@test "remote_branch_checker/remote_branch_checker.sh: existing HTTPS integration remote" {
    git -C "$gitdir" remote set-url integration https://github.com/moodle/integration.git
    export branch="a-branch-which-will-never-exist"
    export issue="MDL-12345"
    export integrateto=main
    export remote="$fixtureremote"

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    refute_output --partial "integration remote not found"
    refute_output --partial "remote integration already exists"
    assert_output --partial "Unable to fetch information from a-branch-which-will-never-exist branch"
    run git -C "$gitdir" config remote.integration.url
    assert_success
    assert_output "https://github.com/moodle/integration.git"
}

@test "remote_branch_checker/remote_branch_checker.sh: missing integration remote defaults to GitHub" {
    git -C "$gitdir" remote remove integration
    export branch="a-branch-which-will-never-exist"
    export issue="MDL-12345"
    export integrateto=main
    export remote="$fixtureremote"

    ci_run remote_branch_checker/remote_branch_checker.sh
    assert_failure
    assert_output --partial "integration remote not found, adding https://github.com/moodle/integration.git"
    assert_output --partial "Unable to fetch information from a-branch-which-will-never-exist branch"
    run git -C "$gitdir" config remote.integration.url
    assert_success
    assert_output "https://github.com/moodle/integration.git"
}

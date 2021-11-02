#!/usr/bin/env bats

load libs/shared_setup

teardown() {
    clean_workspace_directory
}

# Helper to assert remote branch reporter info
# usage: assert_checkstyle fixturename format repo hash
assert_remote_branch_reporter() {
    template=$BATS_TEST_DIRNAME/fixtures/remote_branch_reporter/$1/
    fixture=$WORKSPACE/$1
    format=$2
    repo=$3
    hash=$4
    expected=$BATS_TEST_DIRNAME/fixtures/remote_branch_reporter/$1/smurf.$format

    # Slightly horrible rewriting of paths, else the diff filtering will not
    # work correctly.
    cp -R $template $fixture
    for i in $fixture/*.xml;
    do
      sed -i.bak "s#/var/lib/jenkins/git_repositories/prechecker#$WORKSPACE#g" $i
    done

    testresult=$WORKSPACE/remote_branch_reporter.out

    ci_run_php "remote_branch_checker/remote_branch_reporter.php --directory=$fixture --format=$format --patchset=patchset.xml --repository=$repo --githash=$hash > $testresult"
    assert_success
    assert_files_same $expected $testresult
}

# https://integration.moodle.org/job/Precheck%20remote%20branch/25738/
@test "remote_branch_checker/remote_branch_reporter.php: MDL-55322 no problems html" {
    assert_remote_branch_reporter MDL-55322 html  https://github.com/snake/moodle.git 1326e8dca17e49d5749f559bbb03cc81012b6a90
}
@test "remote_branch_checker/remote_branch_reporter.php: MDL-55322 no problems xml" {
    assert_remote_branch_reporter MDL-55322 xml https://github.com/snake/moodle.git 1326e8dca17e49d5749f559bbb03cc81012b6a90
}

# Replicating https://integration.moodle.org/job/Precheck%20remote%20branch/25634/
@test "remote_branch_checker/remote_branch_reporter.php: MDL-54987 (55 errors/6 warnings) html" {
    assert_remote_branch_reporter MDL-54987 html https://github.com/FMCorz/moodle.git 1869439cb1a12d82ea5bfc22a49527299f9c9620
}
@test "remote_branch_checker/remote_branch_reporter.php: MDL-54987 (55 errors/6 warnings) xml" {
    assert_remote_branch_reporter MDL-54987 xml https://github.com/FMCorz/moodle.git 1869439cb1a12d82ea5bfc22a49527299f9c9620
}

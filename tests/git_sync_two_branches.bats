#!/usr/bin/env bats

load libs/shared_setup

setup_file() {
    # All these tests need a moodle git clone with a remote available, called "local_ci_tests"
    # pointing to the https://git.in.moodle.com/integration/prechecker.git repository.
    cd "${gitdir}"
    git remote add local_ci_tests https://git.in.moodle.com/integration/prechecker.git
    cd $OLDPWD

    # Note that we'll be removing this custom remote at the end of the tests in this file.
}

teardown_file() {
    # Remove the custom remote we added in setup_file.
    cd "${gitdir}"
    git remote remove local_ci_tests
    cd $OLDPWD
}

setup() {
    # Always perform dry runs when testing. We don't want to change the fixture branches.
    cd "${gitdir}"
    export dryrun=1

    # Set the rest of env variables needed for the script.
    export gitremote=local_ci_tests

    # Let's checkout main, so we test everything without any local checkout of the branches.
    git checkout main --quiet
    cd $OLDPWD
}

teardown() {
    # Remove the source and target local branches created for the test.
    # (all them begin with local_ci_git_sync_ prefix).
    cd "${gitdir}"
    git branch --list 'local_ci_git_sync_*' | xargs -r git branch -D --quiet
    cd $OLDPWD
}

@test "git_sync_two_branches: Both branches are in sync" {

    export source=local_ci_git_sync_master
    export target=local_ci_git_sync_main

    run git_sync_two_branches/git_sync_two_branches.sh

    # Assert result.
    assert_success

    assert_output --partial "Syncing local_ci_tests remote"
    assert_output --partial "Set ${target} target branch to ${source} source branch..."
    assert_output --partial "Dry-run enabled"
    assert_output --partial "Creating local source branch ${source}"
    assert_output --partial "Creating local target branch ${target}"
    assert_output --partial "Branches ${source} and ${target} are the same"
    assert_output --partial "Current HEAD: d76e211be6ae65fe"
}

@test "git_sync_two_branches: Both branches have diverged (reset)" {

    export source=local_ci_git_sync_master_diverged
    export target=local_ci_git_sync_main

    run git_sync_two_branches/git_sync_two_branches.sh

    # Assert result.
    assert_success

    assert_output --partial "Diverged branches (surely because of some rewrite"
    assert_output --partial "Hard-resetting target branch ${target} to source branch ${source}"
    assert_output --partial "New HEAD: 150d134fa2d519cd"
}

@test "git_sync_two_branches: There are new commits in source branch (fast forward)" {

    export source=local_ci_git_sync_master_fast_forward
    export target=local_ci_git_sync_main

    run git_sync_two_branches/git_sync_two_branches.sh

    # Assert result.
    assert_success

    assert_output --partial "The source ${source} branch got new commits."
    assert_output --partial "Fast-forwarding target branch ${target} to source branch ${source}"
    assert_output --partial "New HEAD: 5f3a55f6f01142d8"
}

@test "git_sync_two_branches: There are new commits in target branch (error)" {

    export source=local_ci_git_sync_master
    export target=local_ci_git_sync_main_advanced

    run git_sync_two_branches/git_sync_two_branches.sh

    # Assert result.
    assert_failure

    assert_output --partial "The target ${target} branch got new commits."
    assert_output --partial "Error: target ${target} branch has some unexpected commits, not available in the source"
    assert_output --partial "fix the target ${target} branch manually"
    assert_output --partial "Expected HEAD: d76e211be6ae65fe"
}

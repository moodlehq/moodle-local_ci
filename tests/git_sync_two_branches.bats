#!/usr/bin/env bats

load libs/shared_setup

setup_file() {
    # Only the commit histories matter, so use empty commits in a temporary local remote.
    local fixture="$BATS_FILE_TMPDIR/remote.git"
    git init --quiet --bare --initial-branch=main "$fixture"
    git -C "$fixture" config user.name "Local CI"
    git -C "$fixture" config user.email "local_ci@moodle.com"

    local tree basecommit targetcommit
    tree=$(git -C "$fixture" mktree </dev/null)
    basecommit=$(git -C "$fixture" commit-tree "$tree" -m "Common ancestor")
    sourcecommit=$(git -C "$fixture" commit-tree "$tree" -p "$basecommit" -m "Original source")
    divergedcommit=$(git -C "$fixture" commit-tree "$tree" -p "$basecommit" -m "Rewritten source")
    fastforwardcommit=$(git -C "$fixture" commit-tree "$tree" -p "$sourcecommit" -m "New source commit")
    targetcommit=$(git -C "$fixture" commit-tree "$tree" -p "$sourcecommit" -m "Unexpected target commit")
    export sourcecommit divergedcommit fastforwardcommit

    git -C "$fixture" branch main "$basecommit"
    git -C "$fixture" branch local_ci_git_sync_master "$sourcecommit"
    git -C "$fixture" branch local_ci_git_sync_main "$sourcecommit"
    git -C "$fixture" branch local_ci_git_sync_master_diverged "$divergedcommit"
    git -C "$fixture" branch local_ci_git_sync_master_fast_forward "$fastforwardcommit"
    git -C "$fixture" branch local_ci_git_sync_main_advanced "$targetcommit"

    export LOCAL_CI_TESTS_GITDIR="$BATS_FILE_TMPDIR/checkout"
    export gitdir="$LOCAL_CI_TESTS_GITDIR"
    git clone --quiet --origin local_ci_tests "$fixture" "$gitdir"
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
    assert_output --partial "Current HEAD: ${sourcecommit:0:16}"
}

@test "git_sync_two_branches: Both branches have diverged (reset)" {

    export source=local_ci_git_sync_master_diverged
    export target=local_ci_git_sync_main

    run git_sync_two_branches/git_sync_two_branches.sh

    # Assert result.
    assert_success

    assert_output --partial "Diverged branches (surely because of some rewrite"
    assert_output --partial "Hard-resetting target branch ${target} to source branch ${source}"
    assert_output --partial "New HEAD: ${divergedcommit:0:16}"
}

@test "git_sync_two_branches: There are new commits in source branch (fast forward)" {

    export source=local_ci_git_sync_master_fast_forward
    export target=local_ci_git_sync_main

    run git_sync_two_branches/git_sync_two_branches.sh

    # Assert result.
    assert_success

    assert_output --partial "The source ${source} branch got new commits."
    assert_output --partial "Fast-forwarding target branch ${target} to source branch ${source}"
    assert_output --partial "New HEAD: ${fastforwardcommit:0:16}"
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
    assert_output --partial "Expected HEAD: ${sourcecommit:0:16}"
}

#!/usr/bin/env bash

set -e
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

if [ -z $LOCAL_CI_TESTS_CACHEDIR ]; then
    echo "Please define LOCAL_CI_TESTS_CACHEDIR" >&2
    exit 1;
fi

if [ ! -d $LOCAL_CI_TESTS_CACHEDIR ]; then
    echo "Please ensure LOCAL_CI_TESTS_CACHEDIR is a directory" >&2
    exit 1
fi

if [ -z $LOCAL_CI_TESTS_GITDIR ]; then
    echo "Please define LOCAL_CI_TESTS_GITDIR. It should be a git clone of moodle.git." >&2
    echo "IT WILL CAUSE DESTRUCTIVE CHANGES TO THE GIT REPO, DO NOT SHARE IT WITH YOUR CODE!" >&2
    exit 1;
else
    # Ensure $LOCAL_CI_TESTS_GITDIR does not have trailing slashes, it breaks various tests.
    LOCAL_CI_TESTS_GITDIR=$(echo $LOCAL_CI_TESTS_GITDIR | sed -n 's/\/*$//p')
fi

if [ -z $LOCAL_CI_TESTS_PHPCS_DIR ]; then
    echo "Please ensure LOCAL_CI_TESTS_PHPCS_DIR is set to the path to the phpcs standard" >&2
    exit 1
fi

export LANG=C # To ensure that all commands texts are in English

export LOCAL_CI_TESTS_RUNNING=1
export WORKSPACE=$BATS_TMPDIR/workspace
mkdir -p $WORKSPACE
export gitcmd=git
export phpcmd=php
export mysqlcmd=mysql
export gitdir=$LOCAL_CI_TESTS_GITDIR

create_git_branch() {
    branch=$1
    resetto=$2

    cd $gitdir
    $gitcmd checkout . -q
    $gitcmd clean -fd -q
    $gitcmd checkout -B $branch -q
    $gitcmd reset --hard $resetto -q

    export gitbranch=$branch
    cd $OLDPWD # Return to where we were.
}

git_apply_fixture() {
    patchname=$1
    patch=$BATS_TEST_DIRNAME/fixtures/$patchname

    if [ ! -f $patch ];
    then
        echo "Fixture named $patchname does not exist in fixtures directory" 1>&2
        exit 1
    fi

    cd $gitdir
    export FIXTURE_HASH_BEFORE=$($gitcmd rev-parse HEAD)
    $gitcmd am -q $patch
    export FIXTURE_HASH_AFTER=$($gitcmd rev-parse HEAD)
    cd $OLDPWD # Return to where we were.
}

clean_workspace_directory() {
    rm -rf $WORKSPACE
    mkdir $WORKSPACE
}

# Some custom runners which allow use of relative path
# NOTE: we use 'bash -c' to allow piping:
#   -  see https://github.com/sstephenson/bats/issues/10#issuecomment-26627687
ci_run() {
    command="$BATS_TEST_DIRNAME/../$@"
    run bash -c "$command"
}

ci_run_php() {
    command="$BATS_TEST_DIRNAME/../$@"
    run bash -c "php $command"
}

# Assert that files are the same.
# Usage: assert_files_same file1 file2
assert_files_same() {
    expected=$1
    actual=$2

    if [ ! -s $expected ]; then
        fail "$expected is empty"
        return 1
    fi

    if [ ! -s $actual ]; then
        fail "$actual is empty"
        return 1
    fi

    run diff -ruN $expected $actual
    assert_success
    assert_output ''
}

# Get a tmp directory - unique to each test file and run
get_per_file_tmpdir_name() {
    echo "$BATS_TMPDIR/$( echo $BATS_TEST_FILENAME $PPID | md5sum | awk '{ print $1 }' )"
}

# Store the current state of the $WORKSPACE directory for use by other tests in the same file
store_workspace() {
    dir=$(get_per_file_tmpdir_name)
    mkdir -p $dir
    cp -R $WORKSPACE/. $dir
}

restore_workspace() {
    dir=$(get_per_file_tmpdir_name)
    cp -R $dir/. $WORKSPACE
}

# Clever idea, borrowed from https://github.com/dgholz/detect_virtualenv/blob/master/t/begin_and_end.bash
# Are we in the first test of a file?
function first_test() {
  [ "$BATS_TEST_NUMBER" -eq 1 ]
}

# Are we in the last test of a file?
function last_test() {
  [ "$BATS_TEST_NUMBER" -eq "${#BATS_TEST_NAMES[@]}" ]
}

# Clean up any $WORKSPACE state on every run.
clean_workspace_directory

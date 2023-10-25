#!/usr/bin/env bash

# Functions for git_sync_two_branches.sh

# Let's go strict (exit on error)
set -e

# Apply some defaults in case nobody defined them.
BUILD_NUMBER="${BUILD_NUMBER:-0}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
gitcmd="${gitcmd:-git}"
logfile="${WORKSPACE}/git_sync_two_branches.log"

# Utility function to check if a branch is an ancestor of another branch.
# Returns 0 if $1 is an ancestor of $2, 1 otherwise.
function is_ancestor() {
    local branch1=$1
    local branch2=$2
    if ${gitcmd} merge-base --is-ancestor "${branch1}" "${branch2}"; then
        return 0
    else
        return 1
    fi
}

# Utility function to output something both to stdout and to a log file, with some extra information.
function log() {
    echo "$1"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP $1" >> "${logfile}"
}

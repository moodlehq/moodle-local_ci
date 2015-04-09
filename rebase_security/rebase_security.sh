#!/bin/bash
# $WORKSPACE: place for action to take place (will be used as git repo)
# $gitcmd: Path to git executable.
# $integrationremote: Remote where integration is being fetched from
# $securityremote: Remote repo where security branches are being pushed to
# $branch: Remote branch we are going to check.

set -e

function exit_with_error() {
    echo "ERROR: $1"
    exit 1
}

function info() {
    echo "INFO: $1"
}

# Verify everything is set
required="WORKSPACE gitcmd integrationremote securityremote branch"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        exit_with_error "Error: ${var} environment variable is not defined. See the script comments."
    fi
done

if [[ ! -d "$WORKSPACE/.git" ]]; then
    info "Doing initial clone of moodle.git, git repo not found"
    $gitcmd clone git://git.moodle.org/moodle.git "${WORKSPACE}"
fi


# This 'lastbased-master' branch, tracks what the tip of integration.git/master was
# when we last succesfully rebased.
referencebranch="lastbased-$branch"
# TODO: maybe we will switch to just $branch in future for simplicity.
securitybranch="security-$branch"

# Note that this script does not attempt to automtically setup these branches, it should be done
# manually once and once only. If the branches don't exist after then we have a problem.

cd "$WORKSPACE"

# Ensure the remotes exist.
if ! $($gitcmd remote -v | grep '^security[[:space:]]]*' | grep -q $securityremote); then
    info "Adding security remote"
    $gitcmd remote add security $securityremote
fi

if ! $($gitcmd remote -v | grep '^integration[[:space:]]]*' | grep -q $integrationremote); then
    info "Adding integration remote"
    $gitcmd remote add integration $integrationremote
fi

git fetch integration
git fetch security

# Verify that the branch we want to rebase onto exists.
$gitcmd ls-remote --exit-code --heads integration $branch > /dev/null ||
    exit_with_error "Integration branch $branch not found in integration.git. Something serious has gone wrong!"

# Verify that the reference branch exists.
$gitcmd ls-remote --exit-code --heads security $referencebranch > /dev/null ||
    exit_with_error "Reference branch $referencebranch not found in security.git. Needs manual fix."

# Verify that security-branch exists.
$gitcmd ls-remote --exit-code --heads security $securitybranch > /dev/null ||
    exit_with_error "Security branch $securitybranch not found in security.git. Needs manual fix."


info "Cleaning worktree"
$gitcmd clean -dfx
$gitcmd reset --hard

# Set our local wd to current state of security repo.
# (NOTE: checkout -B means create if branch doesn't exist or reset if it does.)
$gitcmd checkout -B $securitybranch security/$securitybranch

# Do the magic!
# ABRACADABRA!!🌟
info "Rebasing security branch:"
if ! ($gitcmd rebase --onto integration/$branch security/$referencebranch)
then
    # rebase failed, abort and exit
    $gitcmd rebase --abort
    exit_with_error "Auto rebase failed, manual conflicts to be resolved by integrator."
fi

info "Force pushing rebased security branch:"
$gitcmd push -f security $securitybranch
info "Force pushing updated reference branch:"
$gitcmd push -f security integration/$branch:$referencebranch

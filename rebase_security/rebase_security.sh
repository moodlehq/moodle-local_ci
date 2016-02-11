#!/bin/bash
# $gitcmd: Path to git executable.
# $gitdir: Directory containing git repo
# $gitbranch: Branch name
# $npmcmd: Path to the npm executable (global)
# $npmbase: Base directory where we'll store multiple npm packages versions (subdirectories per branch)
# $integrationremote: Remote where integration is being fetched from
# $securityremote: Remote repo where security branches are being pushed to

set -e

# Calculate some variables.
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ensure (gruntcmd or (recesscmd and shiftercmd)) are available (depends on $gitbranch)
. ${mydir}/../prepare_npm_stuff/prepare_npm_stuff.sh

moodlecssfile="theme/bootstrapbase/style/moodle.css"
editorcssfile="theme/bootstrapbase/style/editor.css"
jsbuild="/yui/build/"

function exit_with_error() {
    echo "ERROR: $1"
    exit 1
}

function info() {
    echo "INFO: $1"
}

function grunt_available() {
    if [ -f "Gruntfile.js" ]; then
        return 0
    fi
    return 1
}

function compile_less() {

    # Grunt is available since Moodle 2.9, fallback to recess.
    if grunt_available; then
        $gruntcmd "css"
    else
        $recesscmd --compile --compress theme/bootstrapbase/less/moodle.less > "$moodlecssfile"
        $recesscmd --compile --compress theme/bootstrapbase/less/editor.less > "$editorcssfile"
    fi

    $gitcmd add "$moodlecssfile"
    $gitcmd add "$editorcssfile"
}

function compile_js() {

    # Grunt is available since Moodle 2.9, fallback to shifter (only YUI modules before).
    if grunt_available; then
        $gruntcmd "js"
    else
        $shiftercmd --walk --recursive
    fi

    $gitcmd add "*$jsbuild*"
}

function fix_conflict() {

    local jscompiled=""
    local lesscompiled=""

    # We might have multiple conflicts in the same commit.
    $gitcmd diff --name-only --diff-filter=U | \
    while read conflict; do
        if [ "$conflict" == "$moodlecssfile" ] && [ -z "$lesscompiled" ]
        then
            echo "CSS conflict in $conflict"
            compile_less
            lesscompiled=1

        elif [ "$conflict" == "$editorcssfile" ] && [ -z "$lesscompiled" ]
        then
            echo "CSS conflict in $conflict"
            compile_less
            lesscompiled=1

        elif [[ "$conflict" =~ "$jsbuild" ]] && [ -z "$jscompiled" ]
        then
            echo "JS build conflict in $conflict"
            compile_js
            jscompiled=1
        else
            # Rebase failed, abort and exit.
            $gitcmd rebase --abort
            exit_with_error "Auto rebase failed, conflicts couldn't be autoresolved, manual conflicts to be resolved by integrator."
        fi
    done
}

# Verify everything is set.
required="gitcmd gitdir gitbranch npmcmd npmbase integrationremote securityremote"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        exit_with_error "Error: ${var} environment variable is not defined. See the script comments."
    fi
done

if [[ ! -d "$gitdir/.git" ]]; then
    info "Doing initial clone of moodle.git, git repo not found"
    $gitcmd clone git://git.moodle.org/moodle.git "${gitdir}"
fi


# This 'lastbased-master' branch, tracks what the tip of integration.git/master was
# when we last succesfully rebased.
referencebranch="lastbased-$gitbranch"
# TODO: maybe we will switch to just $gitbranch in future for simplicity.
securitybranch="security-$gitbranch"

# Note that this script does not attempt to automtically setup these branches, it should be done
# manually once and once only. If the branches don't exist after then we have a problem.

cd "$gitdir"

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
$gitcmd ls-remote --exit-code --heads integration $gitbranch > /dev/null ||
    exit_with_error "Integration branch $gitbranch not found in integration.git. Something serious has gone wrong!"

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
if ! ($gitcmd rebase --onto integration/$gitbranch security/$referencebranch)
then
    fix_conflict
    until $gitcmd rebase --continue; do
        fix_conflict
    done
fi

info "Force pushing rebased security branch:"
$gitcmd push -f security $securitybranch
info "Force pushing updated reference branch:"
$gitcmd push -f security integration/$gitbranch:$referencebranch

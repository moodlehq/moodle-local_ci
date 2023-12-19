#!/usr/bin/env bash
# WORKSPACE: Path to the workspace directory.
# $gitcmd: Path to git executable.
# $gitdir: Directory containing git repo.
# $gitremote: Remote name where the branches are located. Default: origin.
# $dryrun: If set to anything, the script will not perform any changes.
# $source: Source branch to sync from.
# $target: Target branch to sync to.

# Want exit on error.
set -e

# This script will sync two branches in a git repo given the target branch is an ancestor
# of the source branch. If the opposite is detected (source branch is an ancestor of the
# target branch), the script will exit with an error.
# Everything (compare, send changes...) to the "gitremote" remote, unconditionally.

# Verify everything is set
required="WORKSPACE gitdir gitcmd source target"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
gitdir=${gitdir:-}
gitremote=${gitremote:-origin}
gitcmd=${gitcmd:-git}
source=${source:-main}
target=${target:-main}
dryrun=${dryrun:-}

# Load some functions
source "${mydir}/lib.sh"

# Verify that the git directory is valid and that the remote exits.
cd "${gitdir}"

if ! ${gitcmd} remote | grep -q "^${gitremote}$"; then
    echo "Error: ${gitremote} is not a valid remote."
    exit 1
fi

if ! ${gitcmd} rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: ${gitdir} is not a valid git directory."
    exit 1
fi

# Get the url of the gitremote remote.
remote_url=$(${gitcmd} config --get "remote.${gitremote}.url")

# Verify that the source and target branches exist in the remote.
if ! ${gitcmd} ls-remote --exit-code --heads "${gitremote}" "${source}" > /dev/null 2>&1; then
    echo "Error: ${source} branch does not exist in ${gitremote} remote (${remote_url})."
    exit 1
fi

if ! ${gitcmd} ls-remote --exit-code --heads "${gitremote}" "${target}" > /dev/null 2>&1; then
    echo "Error: ${target} branch does not exist in ${gitremote} remote (${remote_url})."
    exit 1
fi

echo "Syncing ${gitremote} remote (${remote_url}): Set ${target} target branch to ${source} source branch..."

if [ -n "${dryrun}" ]; then
    echo "Dry-run enabled, no changes will be applied to the ${target} branch in ${gitremote} (${remote_url})."
    dryrun="DRY-RUN: "
fi

# Ensure that both the source and target branches exist locally, creating them if necessary.
if ! ${gitcmd} show-ref --verify --quiet "refs/heads/${source}"; then
    echo "Creating local source branch ${source}..."
    "${gitcmd}" fetch --quiet "${gitremote}" "${source}"
    "${gitcmd}" branch --quiet --force "${source}" --track "${gitremote}/${source}"
else
    echo "Updating local source branch ${source}..."
    "${gitcmd}" fetch --quiet "${gitremote}" "${source}:${source}"
fi

if ! ${gitcmd} show-ref --verify --quiet "refs/heads/${target}"; then
    echo "Creating local target branch ${target}..."
    "${gitcmd}" fetch --quiet "${gitremote}" "${target}"
    "${gitcmd}" branch --quiet --force "${target}" --track "${gitremote}/${target}"
else
    echo "Updating local target branch ${target}..."
    "${gitcmd}" fetch --quiet "${gitremote}" "${target}:${target}"
fi

# Let's calculate the commit that will be the HEAD at the end of the process. It's the one in the source branch.
commit_outcome=$(${gitcmd} rev-parse --short=16 "${source}")

# Verify if both branches are the same. If so, we are done.
if is_ancestor "${source}" "${target}" && is_ancestor "${target}" "${source}"; then
    echo "Branches ${source} and ${target} are the same. Nothing to do. Current HEAD: ${commit_outcome}"
    exit 0
fi

# Verify that the source branch is not an ancestor of the target branch.
if is_ancestor "${source}" "${target}"; then
    echo "The target ${target} branch got new commits."
    log "Error: target ${target} branch has some unexpected commits, not available in the source ${source} branch. Expected HEAD: ${commit_outcome}."
    echo "Please, fix the target ${target} branch manually and try again."
    exit 1
fi

# We are good to go with any of the remaining cases.

# Verify that the target branch is an ancestor of the source branch. If so, we can fast-forward.
if is_ancestor "${target}" "${source}"; then
    echo "The source ${source} branch got new commits."
    log "${dryrun}Fast-forwarding target branch ${target} to source branch ${source} at ${gitremote} remote (${remote_url}). New HEAD: ${commit_outcome}"
    "${gitcmd}" fetch --quiet . "${source}:${target}"
    # Self-assert that the operation happened.
    new_commit=$(${gitcmd} rev-parse --short=16 "${target}")
    if [[ "${new_commit}" != "${commit_outcome}" ]]; then
        log "Error: fast-forwarding failed. Expected new HEAD: ${commit_outcome}. Actual new HEAD: ${new_commit}."
        exit 1
    fi
    if [[ -z "${dryrun}" ]]; then
        "${gitcmd}" push "${gitremote}" --quiet "${target}"
    fi
    exit 0
fi

# Arrived here, the source and target branches have diverged. We'll need to do a
# hard reset of the target branch to the source branch.
echo "Diverged branches (surely because of some rewrite in ${source})."
log "${dryrun}Hard-resetting target branch ${target} to source branch ${source} at ${gitremote} remote (${remote_url}). New HEAD: ${commit_outcome}"
"${gitcmd}" branch --quiet --force "${target}" "${source}"
# Self-assert that the operation happened.
new_commit=$(${gitcmd} rev-parse --short=16 "${target}")
if [[ "${new_commit}" != "${commit_outcome}" ]]; then
    log "Error: hard-resetting failed. Expected new HEAD: ${commit_outcome}. Actual new HEAD: ${new_commit}."
    exit 1
fi
if [[ -z "${dryrun}" ]]; then
  "${gitcmd}" push "${gitremote}" --force --quiet "${target}"
fi
exit 0

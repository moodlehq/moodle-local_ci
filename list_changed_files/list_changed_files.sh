#!/usr/bin/env bash
# $gitcmd: Path to the git CLI executable
# $gitdir: Directory containing git repo
# $initialcommit: hash of the initial commit
# $finalcommit: hash of the final commit

# List the modified files in a git repository between 2 commits.
# (relative to the root dir of the git repository)

# Don't be strict. Script has own error control handle
set +e

difffilter=${1:-"ACDMRTUXB"}

# Verify everything is set
required="gitcmd gitdir initialcommit finalcommit"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd ${gitdir}

# verify initial commit exists
${gitcmd} rev-parse --quiet --verify ${initialcommit} > /dev/null
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "Error: initial commit does not exist (${initialcommit})"
    exit 1
fi

# verify final commit exists
${gitcmd} rev-parse --quiet --verify ${finalcommit} > /dev/null
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "Error: final commit does not exist (${finalcommit})"
    exit 1
fi

# verify initial commit is ancestor of final commit
${gitcmd} merge-base --is-ancestor ${initialcommit} ${finalcommit} > /dev/null 2>&1
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "Error: unrelated commits are not comparable (${initialcommit} and ${finalcommit})"
    exit 1
fi

# get all the files changed between both commits (no matter the diffs are empty)
git log --diff-filter=${difffilter} --find-renames=100% --name-only --pretty=oneline --full-index ${initialcommit}..${finalcommit} | \
    grep -vE '^[0-9a-f]{40} ' | sort | uniq

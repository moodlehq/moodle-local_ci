#!/usr/bin/env bash

set -e

# Checks if any commit from $2 issue is present in the specified major branch.
# (since last roll happened, aka, since upstream last commit)
function check_issue () {
    # Fetch the equivalent moodle.git branch (from where we are looking for existing commits).
    ${1} fetch -q git://git.moodle.org/moodle.git ${3#"origin/"}
    if [[ -z $( ${1} log  --grep "${2}" --pretty=oneline --abbrev-commit FETCH_HEAD...${3} ) ]]; then
        # If the 2 branch heads (moodle.git and integration.git are exactly the same... it means that
        # we have just rolled. In those cases, we give the integrator up to 60 minutes to proceed to
        # close the issues. After then, proceed normally, no commits found means error.
        if [[ "$( ${1} rev-parse FETCH_HEAD )" == "$( ${1} rev-parse ${3} )" ]]; then
            if [[ -n $( ${1} log --pretty=oneline --abbrev-commit --after='60 minutes ago' FETCH_HEAD ) ]]; then
                return 0
            fi
        fi
        # Arrived here, it's a problem, commit is missing.
        return 1
    fi
    return 0
}

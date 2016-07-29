#!/usr/bin/env bash

set -e

# Checks if any commit from $2 issue is present in the specified major branch.
function check_issue () {
    if [[ -z $( ${1} log  --grep "${2}" --pretty=oneline --abbrev-commit ${3} ) ]]; then
        return 1
    fi
    return 0
}

#!/bin/bash
# $gitcmd: Path to git executable.
# $gitdir:  Directory containing git repo.
# $gcinterval: Number of runs before performing a manual gc of the repo. Defaults to 25. 0 means disabled.
# $gcaggressiveinterval: Number of runs before performing an aggressive gc of the repo. Defaults to 900. 0 means disabled.

# Want exit on error.
set -e

# Apply some defaults
gcinterval=${gcinterval:-25}
gcaggressiveinterval=${gcaggressiveinterval:-900}

# Verify everything is set
required="gitcmd gitdir"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Verify we are under a git repo.
if [[ ! -d "${gitdir}/.git" ]]; then
    echo "Error: Incorrect or non-git gitdir passed. Please fix it."
    exit 1
fi

cd "${gitdir}"

# Let's verify if a git gc is required.

random=${RANDOM}
if [[ -n "${BUILD_TAG}" ]]; then # Running jenkins, use build number.
    random=${BUILD_NUMBER}
fi

if [[ ${gcaggressiveinterval} -gt 0 ]] && [[ $((${random} % ${gcaggressiveinterval})) -eq 0 ]]; then
    echo "Info: Executing git gc --aggressive"
    ${gitcmd} gc --aggressive --quiet
elif [[ ${gcinterval} -gt 0 ]] && [[ $((${random} % ${gcinterval})) -eq 0 ]]; then
    echo "Info: Executing git gc"
    ${gitcmd} gc --quiet
fi

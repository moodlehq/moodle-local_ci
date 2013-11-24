#!/bin/bash
# $gitcmd: Path to the git CLI executable
# $gitdir: Directory containing git repo
#
# Based on GIT_PREVIOUS_COMMIT and GIT_COMMIT decide if the
# compare_databases.sh step must be executed or can be skipped
# by returning 0 (execute) or 1 (skip) as exit status.
#
# Rules:
# If the modified files DO NOT match any of this, then the tests can
# be skipped:
#   - ^version.php$
#   - install.xml$
#   - install.php$
#   - installlib.php$
#   - upgrade.php$
#   - upgradelib.php$
#
rules=('^version\.php$' 'install\.xml$' 'install\.php$' 'installlib\.php$' 'upgrade\.php$' 'upgradelib\.php$')
# Don't be strict. Script has own error control handle
set +e

# Verify everything is set
required="gitcmd gitdir"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 0
    fi
done

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Verify we have GIT_PREVIOUS_COMMIT and GIT_COMMIT
if [[ -z "${GIT_PREVIOUS_COMMIT}" ]] || [[ -z "${GIT_COMMIT}" ]] ; then
    # Nothing to do, we don't have the information for both commits.
    echo "No commits information available. The job cannot be skipped."
    exit 0
fi

# Verify GIT_PREVIOUS_COMMIT and GIT_COMMIT are different
if [[ "${GIT_PREVIOUS_COMMIT}" == "${GIT_COMMIT}" ]]; then
    # Commits are the same. Job won't be skipped.
    echo "Commits are the same. The job cannot be skipped."
    exit 0
fi

# Create the variables required by list_changed_files.sh and
# invoke it
export initialcommit=${GIT_PREVIOUS_COMMIT}
export finalcommit=${GIT_COMMIT}
mfiles=$(${mydir}/../list_changed_files/list_changed_files.sh)
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # Some error happened with list_changed_files.sh, ignore it
    # (we won't be skipping anything)
    echo "Problems getting the list of changed files. The job cannot be skipped."
    exit 0
fi

# Verify all the changed files against all the rules
matchfound=""
for mfile in ${mfiles} ; do
    echo "Checking ${mfile}"
    for regexp in ${rules[@]} ; do
        if [[ "${mfile}" =~ ${regexp} ]] ; then
            echo "  Matches ${regexp}"
            matchfound=1
        fi
    done
done

# No matches found, we can safely skip the compare_database.sh jobs.
if [[ ${matchfound} -eq 0 ]]; then
    echo "No matching rules found. The job can be skipped safely!"
    exit 1
fi
echo "Matches found. The job cannot be skipped."
exit 0

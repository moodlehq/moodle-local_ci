#!/bin/bash
# $remote: Remote repo where the branch to check resides.
# $branch: Remote branch we are going to check.
# $integrateto: Local branch where the remote branch is going to be integrated.
# $issue: Issue code that requested the precheck. Empty means that Jira won't be notified.

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# List of excluded dirs
set +x
. ${mydir}/../define_excluded/define_excluded.sh
set -x

# Create the work directory where all the tasks will happen/be stored
mkdir work

# Prepare the errors and warnings files
errorfile=${WORKSPACE}/work/errors.txt
touch ${errorfile}

# Checkout pristine copy of the configured branch
cd ${WORKSPACE} && git checkout ${integrateto} && git fetch && git reset --hard origin/${integrateto}

# Create the precheck branch, checking if it exists
branchexists="$( git branch | grep ${integrateto}_precheck | wc -l )"
if [[ ${branchexists} -eq 0 ]]; then
    git checkout -b ${integrateto}_precheck
else
    git checkout ${integrateto}_precheck && git reset --hard origin/${integrateto}
fi

# Fetch the remote branch
set +e
git fetch ${remote} ${branch}
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: Unable to fetch information from ${branch} branch at ${remote}." >> ${errorfile}
    exit ${exitstatus}
fi
set -e

# Look for the common ancestor and its date, warn if too old
set +e
ancestor="$( git rev-list --boundary ${integrateto}...FETCH_HEAD | grep ^- | tail -n1 | cut -c2- )"
if [[ ! ${ancestor} ]]; then
    echo "Error: The ${branch} branch at ${remote} and ${integrateto} don't have any common ancestor." >> ${errorfile}
    exit 1
else
    # Ancestor found, let's see if it's recent (< 14 days, covers last 2 weeklies)
    recentancestor="$( git rev-list --after '14 days ago ' --boundary ${integrateto} | grep ${ancestor} )"
    if [[ ! ${recentancestor} ]]; then
        echo "Warning: The ${branch} branch at ${remote} has not been rebased recently." >> ${errorfile}
    fi
fi
set -e

# Calculate the differences and store them
git diff ${integrateto}_precheck...FETCH_HEAD > ${WORKSPACE}/work/patchset.diff

# Extract the changed files and lines from the patchset
set +e
/opt/local/bin/php /Users/stronk7/git_moodle/ci/local/ci/diff_extract_changes/diff_extract_changes.php \
    --diff=${WORKSPACE}/work/patchset.diff --output=xml > ${WORKSPACE}/work/patchset.xml
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: Unable to generate patchset.xml information." >> ${errorfile}
    exit ${exitstatus}
fi
set -e

# Try to merge the patchset (detecting conflicts)
set +e
/opt/local/bin/git merge FETCH_HEAD
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: The ${branch} branch at ${remote} does not apply clean to ${integrateto}" >> ${errorfile}
    exit ${exitstatus}
fi
set -e

# ########## ########## ########## ##########

# First, we execute all the checks requiring complete site codebase

# Run the db install/upgrade comparison check
# (only if there is any *install* or *upgrade* file involved)

# Run the simpletest unittests

# Run the PHPCPD

# ########## ########## ########## ##########

# Now run all the checks that only need the patchset affected files

# Now we can proceed to delete all the files not being part of the
# patchset and also the excluded paths, because all the remaining checks
# are perfomed against the code introduced by the patchset

# Run the upgrade savepoints checker
# (only if there is any *upgrade* file involved)
cp ${mydir}/../check_upgrade_savepoints/check_upgrade_savepoints.php ${WORKSPACE}
/opt/local/bin/php ${WORKSPACE}/check_upgrade_savepoints.php > ${WORKSPACE}/work/savepoints.txt
rm ${WORKSPACE}/check_upgrade_savepoints.php

# Run the PHPPMD

# Run the PHPCS

# Run the PHPDOCS

# Run the TODOs

# ########## ########## ########## ##########

# Everything has been generated in the work directory, time to generate the
# report and decide what to do with it

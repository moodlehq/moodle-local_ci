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

# Try to merge the patchset (detecting conflicts)
set +e
/opt/local/bin/git merge FETCH_HEAD
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: The ${branch} branch at ${remote} does not apply clean to ${integrateto}" >> ${errorfile}
    exit ${exitstatus}
fi
set -e

# Calculate the differences and store them
git diff ${integrateto}..${integrateto}_precheck > ${WORKSPACE}/work/patchset.diff

# Generate the patches and store them
mkdir patches
git format-patch -o ${WORKSPACE}/work/patches ${integrateto}

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

# Get all the files affected by the patchset, plus the .git and work directories
set +x
echo "${WORKSPACE}/.git
${WORKSPACE}/work
$( grep '<file name=' ${WORKSPACE}/work/patchset.xml | \
    awk -v w="${WORKSPACE}" -F\" '{print w"/"$2}' )" > ${WORKSPACE}/work/patchset.files
set -x

# ########## ########## ########## ##########

# Disable exit-on-error for the rest of the script, it will
# advance no matter of any check returning error. At the end
# we will decide based on gathered information
set +e

# First, we execute all the checks requiring complete site codebase

# Run the db install/upgrade comparison check
# (only if there is any *install* or *upgrade* file involved)

# Run the simpletest unittests

# Run the PHPCPD
/opt/local/bin/php ${mydir}/../copy_paste_detector/copy_paste_detector.php \
    ${excluded_list} --quiet --log-pmd "${WORKSPACE}/work/cpd.xml" ${WORKSPACE}

# ########## ########## ########## ##########

# Now we can proceed to delete all the files not being part of the
# patchset and also the excluded paths, because all the remaining checks
# are perfomed against the code introduced by the patchset

# Remove all the excluded (but .git)
set -e +x
for todelete in ${excluded}; do
    if [[ ${todelete} =~ ".git" ]]; then
        continue
    fi
    rm -fr ${WORKSPACE}/${todelete}
done
set -x

# Remove all the files, but the patchset ones and .git and work
find ${WORKSPACE} -type f | grep -vf ${WORKSPACE}/work/patchset.files | xargs rm

# Remove all the empty dirs remaining, but .git and work
find ${WORKSPACE} -type d -depth -empty -not \( -name .git -o -name work -prune \) -delete

# ########## ########## ########## ##########

# Now run all the checks that only need the patchset affected files

# Disable exit-on-error for the rest of the script, it will
# advance no matter of any check returning error. At the end
# we will decide based on gathered information
set +e

# Run the upgrade savepoints checker, converting it to checkstyle format
cp ${mydir}/../check_upgrade_savepoints/check_upgrade_savepoints.php ${WORKSPACE}
/opt/local/bin/php ${WORKSPACE}/check_upgrade_savepoints.php |
    /opt/local/bin/php ${mydir}/../check_upgrade_savepoints/savepoints2checkstyle.php > "${WORKSPACE}/work/savepoints.xml"

rm ${WORKSPACE}/check_upgrade_savepoints.php

# Run the PHPPMD
/opt/local/bin/php ${mydir}/../project_mess_detector/project_mess_detector.php \
    ${WORKSPACE} xml codesize,unusedcode,design --exclude work --reportfile "${WORKSPACE}/work/pmd.xml"

# Run the PHPCS
/opt/local/bin/php ${mydir}/../coding_standards_detector/coding_standards_detector.php \
    --report=checkstyle --report-file="${WORKSPACE}/work/cs.xml" \
    --standard="${mydir}/../../codechecker/moodle" ${WORKSPACE}

# Run the PHPDOCS (it runs from the CI installation, requires one moodle site installed!)
/opt/local/bin/php ${mydir}/../../moodlecheck/cli/moodlecheck.php \
    --path=${WORKSPACE} --format=xml > "${WORKSPACE}/work/docs.xml"

# ########## ########## ########## ##########

# Everything has been generated in the work directory, generate the report
set -e
/opt/local/bin/php ${mydir}/remote_branch_reporter.php \
    --directory="${WORKSPACE}/work" --format=xml --patchset=patchset.xml > "${WORKSPACE}/work/smurf.xml"

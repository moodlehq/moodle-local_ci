#!/bin/bash
# $gitcmd: Path to git executable.
# $phpcmd: Path to php executable.
# $remote: Remote repo where the branch to check resides.
# $branch: Remote branch we are going to check.
# $integrateto: Local branch where the remote branch is going to be integrated.
# $issue: Issue code that requested the precheck. Empty means that Jira won't be notified.
# $filtering: Report about only modified lines (true), or about the whole files (false)

# Don't want debugging @ start, but want exit on error
set +x
set -e

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set the build display name using jenkins-cli
# Based on issue + integrateto, decide the display name to be used
displayname=""
if [[ ! "${issue}" = "" ]]; then
    if [[ "${integrateto}" = "master" ]]; then
        displayname="${issue}"
    else
        if [[ ${integrateto} =~ ^MOODLE_([0-9]*)_STABLE$ ]]; then
            displayname="${issue}_${BASH_REMATCH[1]}"
        fi
    fi
    java -jar ${mydir}/../jenkins_cli/jenkins-cli.jar -s http://localhost:8080 \
        set-build-display-name "${JOB_NAME}" ${BUILD_NUMBER} ${displayname}
fi

# List of excluded dirs
. ${mydir}/../define_excluded/define_excluded.sh

# Create the work directory where all the tasks will happen/be stored
mkdir work

# Prepare the errors and warnings files
errorfile=${WORKSPACE}/work/errors.txt
touch ${errorfile}

# Checkout pristine copy of the configured branch
cd ${WORKSPACE} && ${gitcmd} checkout ${integrateto} && ${gitcmd} fetch && ${gitcmd} reset --hard origin/${integrateto}

# Create the precheck branch, checking if it exists
branchexists="$( ${gitcmd} branch | grep ${integrateto}_precheck | wc -l )"
if [[ ${branchexists} -eq 0 ]]; then
    ${gitcmd} checkout -b ${integrateto}_precheck
else
    ${gitcmd} checkout ${integrateto}_precheck && ${gitcmd} reset --hard origin/${integrateto}
fi

# Fetch the remote branch
set +e
${gitcmd} fetch ${remote} ${branch}
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: Unable to fetch information from ${branch} branch at ${remote}." >> ${errorfile}
    exit ${exitstatus}
fi
set -e

# Look for the common ancestor and its date, warn if too old
set +e
ancestor="$( ${gitcmd} rev-list --boundary ${integrateto}...FETCH_HEAD | grep ^- | tail -n1 | cut -c2- )"
if [[ ! ${ancestor} ]]; then
    echo "Error: The ${branch} branch at ${remote} and ${integrateto} don't have any common ancestor." >> ${errorfile}
    exit 1
else
    # Ancestor found, let's see if it's recent (< 14 days, covers last 2 weeklies)
    recentancestor="$( ${gitcmd} rev-list --after '14 days ago ' --boundary ${integrateto} | grep ${ancestor} )"
    if [[ ! ${recentancestor} ]]; then
        echo "Warning: The ${branch} branch at ${remote} has not been rebased recently." >> ${errorfile}
    fi
fi
set -e

# Try to merge the patchset (detecting conflicts)
set +e
${gitcmd} merge --no-edit FETCH_HEAD
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: The ${branch} branch at ${remote} does not apply clean to ${integrateto}" >> ${errorfile}
    exit ${exitstatus}
fi
set -e

# Calculate the differences and store them
${gitcmd} diff ${integrateto}..${integrateto}_precheck > ${WORKSPACE}/work/patchset.diff

# Generate the patches and store them
mkdir ${WORKSPACE}/work/patches
${gitcmd} format-patch -o ${WORKSPACE}/work/patches ${integrateto}
cd ${WORKSPACE}/work
zip -r ${WORKSPACE}/work/patches.zip ./patches
rm -fr ${WORKSPACE}/work/patches
cd ${WORKSPACE}

# Extract the changed files and lines from the patchset
set +e
${phpcmd} ${mydir}/../diff_extract_changes/diff_extract_changes.php \
    --diff=${WORKSPACE}/work/patchset.diff --output=xml > ${WORKSPACE}/work/patchset.xml
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: Unable to generate patchset.xml information." >> ${errorfile}
    exit ${exitstatus}
fi
set -e

# Get all the files affected by the patchset, plus the .git and work directories
echo "${WORKSPACE}/.git
${WORKSPACE}/work
$( grep '<file name=' ${WORKSPACE}/work/patchset.xml | \
    awk -v w="${WORKSPACE}" -F\" '{print w"/"$2}' )" > ${WORKSPACE}/work/patchset.files

# ########## ########## ########## ##########

# Disable exit-on-error for the rest of the script, it will
# advance no matter of any check returning error. At the end
# we will decide based on gathered information
set +e

# First, we execute all the checks requiring complete site codebase

# TODO: Run the db install/upgrade comparison check
# (only if there is any *install* or *upgrade* file involved)

# TODO: Run the phpunit unittests

# Run the PHPCPD (commented out 20120823 Eloy)
#${phpcmd} ${mydir}/../copy_paste_detector/copy_paste_detector.php \
#    ${excluded_list} --quiet --log-pmd "${WORKSPACE}/work/cpd.xml" ${WORKSPACE}

# Before deleting all the files not part of the patchest we calculate the
# complete list of valid components (plugins, subplugins and subsystems)
# so later various utilities can use it for their own checks/reports.
# The format of the list is (comma separated):
#    type (plugin, subsystem)
#    name (frankestyle component name)
#    path (full or null)
${phpcmd} ${mydir}/../list_valid_components/list_valid_components.php \
    --basedir="${WORKSPACE}" --absolute=true > "${WORKSPACE}/work/valid_components.txt"

# ########## ########## ########## ##########

# Now we can proceed to delete all the files not being part of the
# patchset and also the excluded paths, because all the remaining checks
# are perfomed against the code introduced by the patchset

# Remove all the excluded (but .git and work)
set -e
for todelete in ${excluded}; do
    if [[ ${todelete} =~ ".git" || ${todelete} =~ "work" ]]; then
        continue
    fi
    rm -fr ${WORKSPACE}/${todelete}
done

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
# (it requires to be installed in the root of the dir being checked)
cp ${mydir}/../check_upgrade_savepoints/check_upgrade_savepoints.php ${WORKSPACE}
${phpcmd} ${WORKSPACE}/check_upgrade_savepoints.php > "${WORKSPACE}/work/savepoints.txt"
cat "${WORKSPACE}/work/savepoints.txt" | ${phpcmd} ${mydir}/../check_upgrade_savepoints/savepoints2checkstyle.php > "${WORKSPACE}/work/savepoints.xml"
rm ${WORKSPACE}/check_upgrade_savepoints.php

# Run the PHPPMD (commented out 20120823 Eloy)
#${phpcmd} ${mydir}/../project_mess_detector/project_mess_detector.php \
#    ${WORKSPACE} xml codesize,unusedcode,design --exclude work --reportfile "${WORKSPACE}/work/pmd.xml"

# Run the PHPCS
${phpcmd} ${mydir}/../coding_standards_detector/coding_standards_detector.php \
    --report=checkstyle --report-file="${WORKSPACE}/work/cs.xml" \
    --standard="${mydir}/../../codechecker/moodle" ${WORKSPACE}

# Run the PHPDOCS (it runs from the CI installation, requires one moodle site installed!)
# (we pass to it the list of valid components that was built before deleting files)
${phpcmd} ${mydir}/../../moodlecheck/cli/moodlecheck.php \
    --path=${WORKSPACE} --format=xml --componentsfile="${WORKSPACE}/work/valid_components.txt" > "${WORKSPACE}/work/docs.xml"

# ########## ########## ########## ##########

# Everything has been generated in the work directory, generate the report, observing $filtering
filter=""
if [[ "${filtering}" = "true" ]]; then
    filter="--patchset=patchset.xml"
fi
set -e
${phpcmd} ${mydir}/remote_branch_reporter.php \
    --directory="${WORKSPACE}/work" --format=xml ${filter} > "${WORKSPACE}/work/smurf.xml"

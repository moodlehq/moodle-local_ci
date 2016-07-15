#!/bin/bash
# $gitcmd: Path to git executable.
# $phpcmd: Path to php executable.
# $jshintcmd: Path to jshint executable.
# $csslintcmd: Path to csslint executable.
# $remote: Remote repo where the branch to check resides.
# $branch: Remote branch we are going to check.
# $integrateto: Local branch where the remote branch is going to be integrated.
# $issue: Issue code that requested the precheck. Empty means that Jira won't be notified.
# $filtering: Report about only modified lines (default, true), or about the whole files (false)
# $format: Format of the final smurf file (xml | html). Defaults to html.
# $maxcommitswarn: Max number of commits accepted per run. Warning if exceeded. Defaults to 10.
# $maxcommitserror: Max number of commits accepted per run. Error if exceeded. Defaults to 100.
# $rebasewarn: Max number of days allowed since rebase. Warning if exceeded. Defaults to 20.
# $rebaseerror: Max number of days allowed since rebase. Error if exceeded. Defaults to 60.
# $extrapath: Extra paths to be available (global)
# $npmcmd: Path to the npm executable (global)
# $npmbase: Base directory where we'll store multiple npm packages versions (subdirectories per branch)

# Don't want debugging @ start, but want exit on error
set +x
set -e

# Let add $extrapath to PATH (for node)
if [[ -n ${extrapath} ]]; then
    export PATH=${PATH}:${extrapath}
fi

# Apply some defaults
filtering=${filtering:-true}
format=${format:-html}
maxcommitswarn=${maxcommitswarn:-10}
maxcommitserror=${maxcommitserror:-100}
rebasewarn=${rebasewarn:-20}
rebaseerror=${rebaseerror:-60}

# And reconvert some variables
export gitdir="${WORKSPACE}"
export gitbranch="${integrateto}"

# Verify everything is set
required="WORKSPACE gitcmd phpcmd jshintcmd csslintcmd remote branch integrateto npmcmd npmbase"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# First of all, we need a clean clone of moodle.git in the repository,
# verify if it's there or no.
if [[ ! -d "$WORKSPACE/.git" ]]; then
    echo "Warn: git not found, proceeding to clone git://git.moodle.org/moodle.git"
    rm -fr "${WORKSPACE}/"
    ${gitcmd} clone git://git.moodle.org/moodle.git "${WORKSPACE}"
fi

cd "${WORKSPACE}"

# Define the integration.git if does not exist.
if ! $(git remote -v | grep -q '^integration[[:space:]]]*git:.*integration.git'); then
    echo "Warn: integration remote not found, adding git://git.moodle.org/integration.git"
    ${gitcmd} remote add integration git://git.moodle.org/integration.git
fi

# Now, ensure the repository in completely clean.
echo "Cleaning worktree"
${gitcmd} clean -dfx
${gitcmd} reset --hard

# Let's verify if a git gc is required.
${mydir}/../git_garbage_collector/git_garbage_collector.sh

# Set the build display name using jenkins-cli
# Based on issue + integrateto, decide the display name to be used
# Do this optionally, only if we are running under Jenkins.
displayname=""
if [[ -n "${BUILD_TAG}" ]] && [[ ! "${issue}" = "" ]]; then
    if [[ "${integrateto}" = "master" ]]; then
        displayname="#${BUILD_NUMBER}:${issue}"
    else
        if [[ ${integrateto} =~ ^MOODLE_([0-9]*)_STABLE$ ]]; then
            displayname="#${BUILD_NUMBER}:${issue}_${BASH_REMATCH[1]}"
        fi
    fi
    echo "Setting build display name: ${displayname}"
    java -jar ${mydir}/../jenkins_cli/jenkins-cli.jar -s http://localhost:8080 \
        set-build-display-name "${JOB_NAME}" ${BUILD_NUMBER} ${displayname}
fi

# Create the work directory where all the tasks will happen/be stored
mkdir ${WORKSPACE}/work

# Prepare the errors and warnings files
errorfile=${WORKSPACE}/work/errors.txt
touch ${errorfile}

# Calculate if the execution is a isplugin one (in order to skip some of the checks)
isplugin=""
if [[ ${issue} =~ ^PLUGIN-[0-9]+$ ]]; then
    isplugin="yes"
    echo "Info: Plugin execution detected ${issue}" | tee -a ${errorfile}
fi

# Fetch everything from remotes
${gitcmd} fetch origin
${gitcmd} fetch integration

# Verify the ${integrateto} branch already exists locally.
if [[ ! $(${gitcmd} rev-parse --quiet --verify ${integrateto}) ]]; then
    echo "Info: The branch ${integrateto} does not exist locally" | tee -a ${errorfile}
    # Verify the remote ${integrateto} branch exists and branch locally tracking it.
    if [[ $(${gitcmd} rev-parse --quiet --verify origin/${integrateto}) ]]; then
        echo "Info: Branch ${integrateto} found at origin. Branching locally tracking it" | tee -a ${errorfile}
        ${gitcmd} branch ${integrateto} --track origin/${integrateto}
    else
        echo "Error: The ${integrateto} branch has not been found neither locally neither at origin." | tee -a ${errorfile}
        exit 1
    fi
fi

# Checkout pristine copy of the configured branch, defaulting to moodle.git (origin remote) one.
${gitcmd} checkout ${integrateto}
# If going to check against moodle.git we always do it from tip, coz it's expected people uses to rebase properly and,
# if they are not, then it's ok to become affected by other changes that may have landed later.
${gitcmd} reset --hard origin/${integrateto}

# We are going to support both checks performed against moodle.git tip (default), and
# integration.git ancestor if found. Will use this variable for that, ensuring
# that NEVER it will point to a hash older than moodle.git tip.
# Get moodle.git (origin) tip as default base commit
baserepository="origin"
basecommit=$(${gitcmd} rev-parse --verify origin/${integrateto})

# Create the precheck branch, checking if it exists, defaulting to moodle.git one.
branchexists="$( ${gitcmd} branch | grep ${integrateto}_precheck | wc -l )"
if [[ ${branchexists} -eq 0 ]]; then
    ${gitcmd} checkout -b ${integrateto}_precheck
else
    ${gitcmd} checkout ${integrateto}_precheck && ${gitcmd} reset --hard origin/${integrateto}
fi

# Fetch the remote branch.
set +e
${gitcmd} fetch ${remote} ${branch}
# record FETCH_HEAD for later
remotesha=$(git rev-parse --verify FETCH_HEAD)
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: Unable to fetch information from ${branch} branch at ${remote}." | tee -a ${errorfile}
    exit ${exitstatus}
fi

# Look for the common ancestor against moodle.git
ancestor="$(${gitcmd} merge-base FETCH_HEAD origin/${integrateto})"
if [[ ! ${ancestor} ]]; then
    echo "Error: The ${branch} branch at ${remote} and moodle.git ${integrateto} do not have any common ancestor." | tee -a ${errorfile}
    exit 1
fi

# Look for the common ancestor against integration.git
integrationancestor="$(${gitcmd} merge-base FETCH_HEAD integration/${integrateto})"
# Not sure if this can happen, just imagining rare cases of rewriting history, with moodle.git passing and this failing.
if [[ ! ${integrationancestor} ]]; then
    echo "Error: The ${branch} branch at ${remote} and integration.git ${integrateto} do not have any common ancestor." | tee -a ${errorfile}
    exit 1
fi

if [[ "${ancestor}" != "${integrationancestor}" ]]; then
    echo -n "Info: moodle.git ancestor: "
    git log --pretty=format:'%h %s' -n1 $ancestor
    echo -n "Info: integration.git ancestor: "
    git log --pretty=format:'%h %s' -n1 $integrationancestor
    # If the moodle.git ancestor is different on the integration.git ancestor, it means the branch is based off integration.
    # so we set the basecommit to point to it.
    ancestor=${integrationancestor}
    baserepository="integration"
    basecommit=${integrationancestor}
    echo "Warn: the branch is based off integration.git" | tee -a ${errorfile}
    # If going to check against integration.git, we issue a warning because it's a non-ideal situation,
    # but given the dynamic nature of that repo, we perform the checks from ancestor and not from tip
    # to avoid being affected by other's ongoing work, already validated by integrators.
    $gitcmd reset --hard ${basecommit}
else
    echo "Info: the branch is based off moodle.git" | tee -a ${errorfile}
fi

echo "Info: base commit "${basecommit}" being used as initial commit." | tee -a ${errorfile}

# Let the tests and checks to start against the known ancestor.

# If ancestor is old (> 60 days) exit asking for mandatory rebase
daysago="${rebaseerror} days ago"
recentancestor="$( ${gitcmd} rev-list --after "'${daysago}'" HEAD | grep ${ancestor} )"
if [[ ! ${recentancestor} ]]; then
    echo "Error: The ${branch} branch at ${remote} is very old (>${daysago}). Please rebase against current ${integrateto}." | tee -a ${errorfile}
    exit 1
fi

# Check ancestor is recent enough (< 14 days, covers last 2 weeklies)
daysago="${rebasewarn} days ago"
recentancestor="$( ${gitcmd} rev-list --after "'${daysago}'" HEAD | grep ${ancestor} )"
if [[ ! ${recentancestor} ]]; then
    echo "Warn: The ${branch} branch at ${remote} has not been rebased recently (>${daysago})." | tee -a ${errorfile}
fi

# Don't use $ancestor from here any more. $basecommit contains the initial commit to be used everywhere.
ancestor=

# Try to merge the patchset (detecting conflicts) against the decided basecommit (already checkedout above).
${gitcmd} merge --no-edit FETCH_HEAD
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: The ${branch} branch at ${remote} does not apply clean to ${baserepository}/${integrateto}" | tee -a ${errorfile}
    exit ${exitstatus}
fi
set -e

# Verify the number of commits. Now this is handled by the verify_commit_messages check.

# Calculate the differences and store them
${gitcmd} diff ${basecommit}..${integrateto}_precheck > ${WORKSPACE}/work/patchset.diff

# Generate the patches and store them
mkdir ${WORKSPACE}/work/patches
${gitcmd} format-patch -o ${WORKSPACE}/work/patches ${basecommit}
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
    echo "Error: Unable to generate patchset.xml information." | tee -a ${errorfile}
    exit ${exitstatus}
fi
set -e

# Get all the files affected by the patchset, plus the .git and work directories
echo "${WORKSPACE}/.git
${WORKSPACE}/work
$( grep '<file name=' ${WORKSPACE}/work/patchset.xml | \
    awk -v w="${WORKSPACE}" -F\" '{print w"/"$2}' )" > ${WORKSPACE}/work/patchset.files

# Trim patchset.files from any blank line (cannot use in-place sed).
sed '/^$/d' ${WORKSPACE}/work/patchset.files > ${WORKSPACE}/work/patchset.files.tmp
mv ${WORKSPACE}/work/patchset.files.tmp ${WORKSPACE}/work/patchset.files

# Add linting config files to patchset files to avoid it being deleted for use later..
echo '.jshint' >> ${WORKSPACE}/work/patchset.files
echo '.csslintrc' >> ${WORKSPACE}/work/patchset.files
echo '.eslintrc' >> ${WORKSPACE}/work/patchset.files
echo '.eslintignore' >> ${WORKSPACE}/work/patchset.files

# List of excluded paths
. ${mydir}/../define_excluded/define_excluded.sh

echo "List of excluded paths"
echo "${excluded}"
echo

# Everything is ready, let's install all the required node stuff that some tools will use.
${mydir}/../prepare_npm_stuff/prepare_npm_stuff.sh
# And unset npmbase because we don't want those tools to handle node_modules themselves
npmbase=

# Before deleting all the files not part of the patchest we calculate the
# complete list of valid components (plugins, subplugins and subsystems)
# so later various utilities can use it for their own checks/reports.
# The format of the list is (comma separated):
#    type (plugin, subsystem)
#    name (frankestyle component name)
#    path (full or null)
# For 2.6 and upwards the list of components is calculated for the branch
# being checked (100% correct behavior). For previous branches we are using
# the list of components available in the moodle-ci-site, because getting
# the list from the checked branch does require installing the site completely and
# that would slowdown the checker a lot. It's ok 99% of times.
${phpcmd} ${mydir}/../list_valid_components/list_valid_components.php \
    --basedir="${WORKSPACE}" --absolute=true > "${WORKSPACE}/work/valid_components.txt"

# ########## ########## ########## ##########

# Disable exit-on-error for the rest of the script, it will
# advance no matter of any check returning error. At the end
# we will decide based on gathered information
set +e

# First, we execute all the checks requiring complete site codebase

# Set some variables used by various scripts.
export issuecode=${issue}
export maxcommitswarn=${maxcommitswarn}
export maxcommitserror=${maxcommitserror}
export initialcommit=${basecommit}
export GIT_PREVIOUS_COMMIT=${initialcommit}
export finalcommit=${integrateto}_precheck
export GIT_COMMIT=${finalcommit}

# TODO: Run the db install/upgrade comparison check
# (only if there is any *install* or *upgrade* file involved)

# TODO: Run the unit tests for the affected components

# TODO: Run the acceptance tests for the affected components

# Run the commit checker (verify_commit_messages)
# We skip this if the requested build is $isplugin
if [[ -z "${isplugin}" ]]; then
    echo "Checking commit messages..."
    ${mydir}/../verify_commit_messages/verify_commit_messages.sh > "${WORKSPACE}/work/commits.txt"
    cat "${WORKSPACE}/work/commits.txt" | ${phpcmd} ${mydir}/../verify_commit_messages/commits2checkstyle.php > "${WORKSPACE}/work/commits.xml"
fi

# Run the php linter (php_lint)
echo "Running php lint..."
${mydir}/../php_lint/php_lint.sh > "${WORKSPACE}/work/phplint.txt"
cat "${WORKSPACE}/work/phplint.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=phplint > "${WORKSPACE}/work/phplint.xml"

${mydir}/../thirdparty_check/thirdparty_check.sh > "${WORKSPACE}/work/thirdparty.txt"
echo "Checking thirdparty changes..."
cat "${WORKSPACE}/work/thirdparty.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=thirdparty > "${WORKSPACE}/work/thirdparty.xml"

# Run the grunt checker if Gruntfile exists. node stuff has been already installed.
if [ -f ${WORKSPACE}/Gruntfile.js ]; then
    echo "Running grunt..."
    ${mydir}/../grunt_process/grunt_process.sh > "${WORKSPACE}/work/grunt.txt" 2> "${WORKSPACE}/work/grunt-errors.txt"
    cat "${WORKSPACE}/work/grunt.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=gruntdiff > "${WORKSPACE}/work/grunt.xml"
    cat "${WORKSPACE}/work/grunt-errors.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=shifter > "${WORKSPACE}/work/shifter.xml"
fi

if [[ -z "${isplugin}" ]]; then
    echo "Checking integrated issues fixfor versions and branches..."
    ${phpcmd} ${mydir}/../travis/check_branch_status.php --repository=$remote --branch=$branch > "${WORKSPACE}/work/travis.txt"
    cat "${WORKSPACE}/work/travis.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=travis > "${WORKSPACE}/work/travis.xml"
fi


# ########## ########## ########## ##########

# Now we can proceed to delete all the files not being part of the
# patchset and also the excluded paths, because all the remaining checks
# are perfomed against the code introduced by the patchset
echo "Deleting excluded and unrelated files..."

# Remove all the excluded (but .git and work)
set -e
for todelete in ${excluded}; do
    if [[ ${todelete} =~ ".git" || ${todelete} =~ "work" ]]; then
        continue
    fi
    rm -fr "${WORKSPACE}/${todelete}"
done

# Remove all the files, but the patchset ones and .git and work
find ${WORKSPACE} -type f -and -not \( -path "*/.git/*" -or -path "*/work/*" \) | \
    grep -vf ${WORKSPACE}/work/patchset.files | xargs -I{} rm {}

# Remove all the empty dirs remaining, but .git and work
find ${WORKSPACE} -type d -depth -empty -and -not \( -name .git -or -name work \) -delete

# ########## ########## ########## ##########

# Disable exit-on-error for the rest of the script, it will
# advance no matter of any check returning error. At the end
# we will decide based on gathered information
set +e

# Now run all the checks that only need the patchset affected files

if [ -f $WORKSPACE/.eslintrc ]; then
    echo "Running eslint..."
    eslintcmd="$(${npmcmd} bin)"/eslint
    if [ -x $eslintcmd ]; then
        $eslintcmd -f checkstyle $WORKSPACE > "${WORKSPACE}/work/eslint.xml"
    else
        echo "Error: .eslintrc file found, but eslint executable not found" | tee -a ${errorfile}
        exit 1
    fi
fi

# Don't need node stuff anymore, avoid it being analysed by any of the next tools.
rm ${gitdir}/node_modules

# Run the upgrade savepoints checker, converting it to checkstyle format
# (it requires to be installed in the root of the dir being checked)
echo "Checking upgrade savepoints..."
cp ${mydir}/../check_upgrade_savepoints/check_upgrade_savepoints.php ${WORKSPACE}
${phpcmd} ${WORKSPACE}/check_upgrade_savepoints.php > "${WORKSPACE}/work/savepoints.txt"
cat "${WORKSPACE}/work/savepoints.txt" | ${phpcmd} ${mydir}/../check_upgrade_savepoints/savepoints2checkstyle.php > "${WORKSPACE}/work/savepoints.xml"
rm ${WORKSPACE}/check_upgrade_savepoints.php

# Run the PHPCS
echo "Running codesniffer..."
${phpcmd} ${mydir}/../coding_standards_detector/coding_standards_detector.php \
    --report=checkstyle --report-file="${WORKSPACE}/work/cs.xml" \
    --extensions=php --standard="${mydir}/../../codechecker/moodle" ${WORKSPACE}

# Run the PHPDOCS (it runs from the CI installation, requires one moodle site installed!)
# (we pass to it the list of valid components that was built before deleting files)
echo "Running phpdocs checker..."
${phpcmd} ${mydir}/../../moodlecheck/cli/moodlecheck.php \
    --path=${WORKSPACE} --format=xml --componentsfile="${WORKSPACE}/work/valid_components.txt" > "${WORKSPACE}/work/docs.xml"

# Exclude build directories from the results (e.g. lib/yui/build, lib/amd/build/)
find $WORKSPACE -type d -path \*/build | sed "s|$WORKSPACE/||" > $WORKSPACE/.jshintignore

# Run jshint if we haven't got eslint results
if [ ! -f  "${WORKSPACE}/work/eslint.xml" ]; then
    echo "Running jshint..."
    ${jshintcmd} --config $WORKSPACE/.jshintrc --exclude-path $WORKSPACE/.jshintignore \
        --reporter=checkstyle ${WORKSPACE} > "${WORKSPACE}/work/jshint.xml"
fi

# Run CSSLINT
echo "Running csslint..."
if [ ! -f ${WORKSPACE}/.csslintrc ]; then
    echo "csslintrc file not found, defaulting to error checking only"
    echo '--errors=errors' > ${WORKSPACE}/.csslintrc
    echo '--exclude-list=vendor/,lib/editor/tinymce/,lib/yuilib/,theme/bootstrapbase/style/' >> ${WORKSPACE}/.csslintrc
fi

${csslintcmd} --format=checkstyle-xml --quiet ${WORKSPACE} > "${WORKSPACE}/work/csslint.out"
# Unfortunately csslint doesn't give us decent error codes.. so we have to grep:
if grep -q '<?xml' ${WORKSPACE}/work/csslint.out
then
    echo "csslint check completed."
    mv ${WORKSPACE}/work/csslint.out ${WORKSPACE}/work/csslint.xml
elif grep -q 'No files specified.' ${WORKSPACE}/work/csslint.out
then
    echo "No checkable CSS files detected in patchset."
    echo '<?xml version="1.0" encoding="utf-8"?><checkstyle></checkstyle>' > "${WORKSPACE}/work/csslint.xml"
else
    echo "Error: Unknown csslint error occured. See csslint.out" >> ${errorfile}
    echo 'csslint exited with error:'
    cat ${WORKSPACE}/work/csslint.out
    exit 1
fi

# ########## ########## ########## ##########

# Everything has been generated in the work directory, generate the report, observing $filtering
filter=""
if [[ "${filtering}" = "true" ]]; then
    filter="--patchset=patchset.xml"
fi
set -e
# Since MDLSITE-3423 we unconditionally create the xml file for later use.
${phpcmd} ${mydir}/remote_branch_reporter.php \
    --repository=$remote --githash=$remotesha \
    --directory="${WORKSPACE}/work" --format=xml ${filter} > "${WORKSPACE}/work/smurf.xml"

# And, if another format has been requested, also generate it.
if [[ "${format}" != "xml" ]]; then
    ${phpcmd} ${mydir}/remote_branch_reporter.php \
        --repository=$remote --githash=$remotesha \
        --directory="${WORKSPACE}/work" --format=${format} ${filter} > "${WORKSPACE}/work/smurf.${format}"
fi

# Look for condensed result in the XML file and output it.
condensedresult=$(sed -n -e 's/.*condensedresult="\(smurf[^"]*\)".*/\1/p' "${WORKSPACE}/work/smurf.xml")

echo "SMURFRESULT: ${condensedresult}"

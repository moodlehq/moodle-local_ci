#!/usr/bin/env bash
# $gitcmd: Path to git executable.
# $phpcmd: Path to php executable.
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
# $npmcmd: Optional, path to the npm executable (global)
# $pushremote: (optional) Remote to push the results of prechecker to. Will create branches like MDL-1234-main-shorthash
# $resettocommit: (optional) Should not be used in production runs. Reset $integrateto to a commit for testing purposes.

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE gitcmd phpcmd remote branch integrateto issue"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Apply some defaults
filtering=${filtering:-true}
format=${format:-html}
maxcommitswarn=${maxcommitswarn:-10}
maxcommitserror=${maxcommitserror:-100}
rebasewarn=${rebasewarn:-20}
rebaseerror=${rebaseerror:-60}
npmcmd=${npmcmd:-npm}

# And reconvert some variables
export gitdir="${WORKSPACE}"
export gitbranch="${integrateto}"

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
emptycheckstyle='<?xml version="1.0" encoding="utf-8"?><checkstyle></checkstyle>'

# First of all, we need a clean clone of moodle.git in the repository,
# verify if it's there or no.
if [[ ! -d "$WORKSPACE/.git" ]]; then
    echo "Warn: git not found, proceeding to clone git://git.moodle.org/moodle.git"
    rm -fr "${WORKSPACE}/"
    ${gitcmd} clone -q git://git.moodle.org/moodle.git "${WORKSPACE}"
fi

cd "${WORKSPACE}"

# Define the integration.git if does not exist.
if ! $(git remote -v | grep -q '^integration[[:space:]]]*git:.*integration.git'); then
    echo "Warn: integration remote not found, adding git://git.moodle.org/integration.git"
    ${gitcmd} remote add integration git://git.moodle.org/integration.git
fi

# We are into a _precheck branch from previous run. We don't like any leftover
# so let's delete it drastically. Will be recreated later if needed.
currentbranch=$(${gitcmd} rev-parse --abbrev-ref HEAD)
if [[ ${currentbranch} =~ _precheck$ ]]; then
    echo "Info: Deleting ${currentbranch} branch from previous execution"
    basebranch=${currentbranch%_precheck}
    ${gitcmd} reset --hard origin/${basebranch}
    ${gitcmd} checkout -q -B ${basebranch} origin/${basebranch}
    ${gitcmd} branch -D ${currentbranch}
fi

# Now, ensure the repository in completely clean.
echo "Info: Cleaning worktree"
${gitcmd} clean -q -dfx
${gitcmd} reset -q --hard

# Let's verify if a git gc is required.
${mydir}/../git_garbage_collector/git_garbage_collector.sh

# Set the build display name using jenkins-cli (if configured)
# Based on issue + integrateto, decide the display name to be used
# Do this optionally, only if we are running under Jenkins and decided
# to connect to it using jenkins cli..
displayname=""
if [[ -n "${BUILD_TAG}" ]] && [[ ! "${issue}" = "" ]] && [[ -n "${jenkinsserver}" ]]; then
    if [[ "${integrateto}" = "main" ]]; then
        displayname="#${BUILD_NUMBER}:${issue}"
    else
        if [[ ${integrateto} =~ ^MOODLE_([0-9]*)_STABLE$ ]]; then
            displayname="#${BUILD_NUMBER}:${issue}_${BASH_REMATCH[1]}"
        fi
    fi
    echo "Info: Setting build display name: ${displayname}"
    java -jar ${mydir}/../jenkins_cli/jenkins-cli.jar -s ${jenkinsserver} \
        set-build-display-name "${JOB_NAME}" ${BUILD_NUMBER} ${displayname} < /dev/null
fi

# Create the work directory where all the tasks will happen/be stored
mkdir -p ${WORKSPACE}/work

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
${gitcmd} fetch -q origin
${gitcmd} fetch -q integration

if [[ ! $(${gitcmd} rev-parse --quiet --verify origin/${integrateto}) ]]; then
    echo "Error: The ${integrateto} branch has not been found neither locally neither at origin." | tee -a ${errorfile}
    exit 1
fi

# We are going to support both checks performed against moodle.git tip (default), and
# integration.git ancestor if found. Will use this variable for that, ensuring
# that NEVER it will point to a hash older than moodle.git tip.
# Get moodle.git (origin) tip as default base commit
baseref="origin/${integrateto}"
integrationbaseref="integration/${integrateto}"


if [[ -n "${resettocommit}" ]]; then
    # If we are testing..
    baseref=$resettocommit
    integrationbaseref=$resettocommit
fi

basecommit=$(${gitcmd} rev-parse --verify ${baseref})

# Create the precheck branch
# (NOTE: checkout -B means create if branch doesn't exist or reset if it does.)
${gitcmd} checkout -q -B ${integrateto}_precheck $baseref

# Get information about the branch where the patch is going to be integrated (from version.php).
if [[ -d "public" || -f "public/version.php" ]]; then
    branchline=$(grep "^\$branch\s*=\s*'[0-9]\+';" public/version.php || true)
else
    branchline=$(grep "^\$branch\s*=\s*'[0-9]\+';" version.php || true)
fi

if [[ -z "${branchline}" ]]; then
    echo "Error: Unable to find the branch information in version.php or public/version.php." | tee -a ${errorfile}
    exit 1
fi
# Extract the branch version from the line.
if [[ "${branchline}" =~ \$branch[[:space:]]+=[[:space:]]+\'([0-9]+)\'\; ]]; then
    versionbranch=${BASH_REMATCH[1]}
else
    echo "Error: Unable to extract the branch version from version.php or public/version.php." | tee -a ${errorfile}
    exit 1
fi
echo "Info: The branch ${integrateto} has version.php or public/version.php \$branch: ${versionbranch}" | tee -a ${errorfile}

# Do some cleanup onto the passed details

# Trim whitespace in branch/remote
remote=${remote//[[:blank:]]/}
branch=${branch//[[:blank:]]/}

# Convert github urls into raw branch (MDLSITE-3758).
if [[ "$branch" =~ ^https://github.com/([^/]*)/([^/]*)/tree/(.*)$ ]]
then
    echo "Warn: the branch $branch should not be specified as a github url. Converting to '${BASH_REMATCH[3]}' for prechecker'" | tee -a ${errorfile}
    branch=${BASH_REMATCH[3]}
fi

if [[ "$remote" =~ ^git://github.com.*$ ]]
then
    newremote="$(echo $remote | sed 's@git://github.com@https://github.com@')"
    echo "Warn: the remote '$remote' is using an unauthenticated github url which is no longer supported. Converting to '${newremote}'" | tee -a ${errorfile}
    remote="${newremote}"
fi

# Fetch the remote branch.
if ! ${gitcmd} fetch -q ${remote} ${branch}
then
    echo "Error: Unable to fetch information from ${branch} branch at ${remote}." | tee -a ${errorfile}
    exit 1
fi

remotesha=$(git rev-parse --verify FETCH_HEAD)

set +e
# Look for the common ancestor against moodle.git
ancestor="$(${gitcmd} merge-base FETCH_HEAD $baseref)"
if [[ ! ${ancestor} ]]; then
    echo "Error: The ${branch} branch at ${remote} and moodle.git ${integrateto} do not have any common ancestor." | tee -a ${errorfile}
    exit 1
fi

# Look for the common ancestor against integration.git
integrationancestor="$(${gitcmd} merge-base FETCH_HEAD $integrationbaseref)"
# Not sure if this can happen, just imagining rare cases of rewriting history, with moodle.git passing and this failing.
if [[ ! ${integrationancestor} ]]; then
    echo "Error: The ${branch} branch at ${remote} and integration.git ${integrateto} do not have any common ancestor." | tee -a ${errorfile}
    exit 1
fi

if [[ "${ancestor}" != "${integrationancestor}" ]]; then
    echo -n "Info: moodle.git ancestor: "
    git log --pretty=format:'%h %s' -n1 $ancestor
    echo ""
    echo -n "Info: integration.git ancestor: "
    git log --pretty=format:'%h %s' -n1 $integrationancestor
    echo ""
    # If the moodle.git ancestor is different on the integration.git ancestor, it means the branch is based off integration.
    # so we set the basecommit to point to it.
    ancestor=${integrationancestor}
    baseref="integration/${integrateto}"
    basecommit=${integrationancestor}
    echo "Warn: the branch is based off integration.git" | tee -a ${errorfile}
    # If going to check against integration.git, we issue a warning because it's a non-ideal situation,
    # but given the dynamic nature of that repo, we perform the checks from ancestor and not from tip
    # to avoid being affected by other's ongoing work, already validated by integrators.
    $gitcmd reset -q --hard ${basecommit}
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
echo "Info: Attempting merge to ${baseref}"
${gitcmd} merge -q --no-edit FETCH_HEAD
exitstatus=${PIPESTATUS[0]}
if [[ ${exitstatus} -ne 0 ]]; then
    echo "Error: The ${branch} branch at ${remote} does not apply clean to ${baseref}" | tee -a ${errorfile}

    mergeconflicts="$( ${gitcmd} diff --name-only --diff-filter=U )"
    if [[ -n "${mergeconflicts}" ]]; then
        echo "Error: Merge conflict(s) in file(s):" | tee -a ${errorfile}
        echo "${mergeconflicts}" | sed 's/^/Error: /' | tee -a ${errorfile}
    fi

    exit ${exitstatus}
fi
set -e

# The merge succeded, now push our precheck branch for inspection:
if [ ! -z ${pushremote} ]; then
    echo "Info: Pushing precheck branch to remote"
    # Let's name the branches using 16 chars short commit of the branch being
    # analysed, that way we can know which commits have been already checked.
    # The name will be like MDL-1234-main-abcdef12-12345678, where:
    # - MDL-1234 is the issue being checked.
    # - main is the upstream branch where the patch is being checked against.
    # - abcdef12 is the short commit (belonging to the branch above) where we are merging the patch to.
    # - 12345678 is the short commit of the patch being checked.
    pushbranchname=${issue}-${integrateto}-$(git rev-parse --short=16 "${baseref}")-$(git rev-parse --short=16 FETCH_HEAD)
    # Use --force, no matter that, if the branch already exists it means that the very same base+patch
    # has been already checked previously. Maybe in the future we'll detect this, but not for now.
    $gitcmd push --force "${pushremote}" "${integrateto}_precheck:${pushbranchname}"
fi

# Verify the number of commits. Now this is handled by the verify_commit_messages check.

# Calculate the differences and store them
${gitcmd} diff ${basecommit}..${integrateto}_precheck > ${WORKSPACE}/work/patchset.diff

# Generate the patches and store them
echo "Info: Generating patches"
mkdir ${WORKSPACE}/work/patches
${gitcmd} format-patch -q -o ${WORKSPACE}/work/patches ${basecommit}
cd ${WORKSPACE}/work
zip -q -r ${WORKSPACE}/work/patches.zip ./patches
rm -fr ${WORKSPACE}/work/patches
cd ${WORKSPACE}

# Extract the changed files and lines from the patchset
set +e
echo "Info: Extracting diff changes"
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

# For 4.5 and up, verify that the we aren't modifying any upgrade.txt or UPGRADING.md files.
if [[ ${versionbranch} -ge 405 ]]; then
    if grep -q 'UPGRADING.md\|upgrade.txt' ${WORKSPACE}/work/patchset.files; then
        echo "Error: The patchset contains changes to upgrade.txt or UPGRADING.md files." | tee -a ${errorfile}

        dirtyupgrades="$( grep 'UPGRADING.md\|upgrade.txt' ${WORKSPACE}/work/patchset.files )"
        if [[ -n "${dirtyupgrades}" ]]; then
            echo "Error: File(s) affected:" | tee -a ${errorfile}
            echo "${dirtyupgrades}" | sed "/^${WORKSPACE}//g" | sed 's/^/Error: /' | tee -a ${errorfile}
        fi
    fi
fi

# Add version.php or public/version.php and config-dist.php to patchset files because they
# allow us to find moodle dirroot and branch later.
if [[ -d "public" || -f "public/version.php" ]]; then
    echo "${WORKSPACE}/public/version.php" >> ${WORKSPACE}/work/patchset.files
else
    echo "${WORKSPACE}/version.php" >> ${WORKSPACE}/work/patchset.files
fi
echo "${WORKSPACE}/config-dist.php" >> ${WORKSPACE}/work/patchset.files

# Add linting config files to patchset files to avoid it being deleted for use later..
echo '.eslintrc' >> ${WORKSPACE}/work/patchset.files
echo '.eslintignore' >> ${WORKSPACE}/work/patchset.files
echo '.stylelintrc' >> ${WORKSPACE}/work/patchset.files
echo '.stylelintignore' >> ${WORKSPACE}/work/patchset.files
echo '.gherkin-lintrc' >> ${WORKSPACE}/work/patchset.files

echo "Info: Calculating excluded files"
. ${mydir}/../define_excluded/define_excluded.sh

echo "Info: Preparing npm"
# Everything is ready, let's install all the required node stuff that some tools will use.
source ${mydir}/../prepare_npm_stuff/prepare_npm_stuff.sh >> "${WORKSPACE}/work/prepare_npm.txt" 2>&1

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
echo "Info: Calculating valid components..."
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
export isplugin=${isplugin}

# TODO: Run the db install/upgrade comparison check
# (only if there is any *install* or *upgrade* file involved)

# TODO: Run the unit tests for the affected components

# TODO: Run the acceptance tests for the affected components

# Run the commit checker (verify_commit_messages)
# We skip this if the requested build is $isplugin
if [[ -z "${isplugin}" ]]; then
    echo "Info: Running commits..."
    ${mydir}/../verify_commit_messages/verify_commit_messages.sh > "${WORKSPACE}/work/commits.txt"
    cat "${WORKSPACE}/work/commits.txt" | ${phpcmd} ${mydir}/../verify_commit_messages/commits2checkstyle.php > "${WORKSPACE}/work/commits.xml"
fi

# Run the php linter (php_lint)
echo "Info: Running phplint..."
${mydir}/../php_lint/php_lint.sh > "${WORKSPACE}/work/phplint.txt"
cat "${WORKSPACE}/work/phplint.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=phplint > "${WORKSPACE}/work/phplint.xml"

echo "Info: Running thirdparty..."
${mydir}/../thirdparty_check/thirdparty_check.sh > "${WORKSPACE}/work/thirdparty.txt"
cat "${WORKSPACE}/work/thirdparty.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=thirdparty > "${WORKSPACE}/work/thirdparty.xml"

# We skip this if the requested build is $isplugin
if [[ -z "${isplugin}" ]]; then
    echo "Info: Running missing external/backup stuff..."
    ${mydir}/../upgrade_external_backup_check/upgrade_external_backup_check.sh > "${WORKSPACE}/work/externalbackup.txt"
    cat "${WORKSPACE}/work/externalbackup.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=thirdparty > "${WORKSPACE}/work/externalbackup.xml"
fi

echo "Info: Running mustache lint..."
${mydir}/../mustache_lint/mustache_lint.sh > "${WORKSPACE}/work/mustachelint.txt"
cat "${WORKSPACE}/work/mustachelint.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=mustachelint > "${WORKSPACE}/work/mustachelint.xml"

if [ -f $WORKSPACE/.gherkin-lintrc ]; then
    echo "Info: Running gherkin-lint..."
    if ! ${npmcmd} list --depth=1 --parseable | grep -q gherkin-lint; then
        echo "Error: .gherkin-lintrc file found, but gherkin-lint package not found" | tee -a ${errorfile}
        exit 1
    fi

    # Run gherkin-lint
    npx gherkin-lint --format=json '**/tests/behat/*.feature' 2> "${WORKSPACE}/work/gherkin-lint.txt"
    cat "${WORKSPACE}/work/gherkin-lint.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=gherkinlint > "${WORKSPACE}/work/gherkin-lint.xml"
fi

# Time for grunt results to be checked (conditionally).
touch "${WORKSPACE}/work/grunt.txt"
touch "${WORKSPACE}/work/grunt-errors.txt"

# First, let's calculate if there is any .css / .scss / .less / .map / .js in the patch.
gruntneeded=
if grep -Eq '(\.css|\.scss|\.less|\.js|\.map)$' "${WORKSPACE}/work/patchset.files"; then
    gruntneeded=1
fi

# Run the grunt checker if Gruntfile exists (node stuff has been already installed) and
# if it's really needed to run grunt (gruntneeded), because it's slow.
if [[ -f ${WORKSPACE}/Gruntfile.js ]] && [[ -n "${gruntneeded}" ]]; then
    echo "Info: Running grunt..."
    ${mydir}/../grunt_process/grunt_process.sh > "${WORKSPACE}/work/grunt.txt" 2> "${WORKSPACE}/work/grunt-errors.txt"
else
    echo "Info: Skipping grunt..."
fi

# Always run the converter, so we get the needed xml files to ensure the grunt & shifter sections are always present.
cat "${WORKSPACE}/work/grunt.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=gruntdiff > "${WORKSPACE}/work/grunt.xml"
cat "${WORKSPACE}/work/grunt-errors.txt" | ${phpcmd} ${mydir}/checkstyle_converter.php --format=shifter > "${WORKSPACE}/work/shifter.xml"

# TODO: Maybe add a GHA checker to see if the user has them enabled? 99% of times they will, but can be checked with just
# a quick http request (without looking to more details using the API.

# ########## ########## ########## ##########

# Now we can proceed to delete all the files not being part of the
# patchset and also the excluded paths, because all the remaining checks
# are perfomed against the code introduced by the patchset
echo "Info: Deleting excluded and unrelated files..."

# Remove all the excluded (but .git and work)
set -e
for todelete in ${excluded}; do
    if [[ ${todelete} =~ ".git" || ${todelete} =~ ^work/ || ${todelete} =~ "node_modules" ]]; then
        continue
    fi
    rm -fr "${WORKSPACE}/${todelete}"
done

# Remove all the files, but the patchset ones and .git, work and node_modules
find ${WORKSPACE} -type f -and -not \( \
    -path "/${WORKSPACE}/.git/*" -or -path "${WORKSPACE}/work/*" -or -path "${WORKSPACE}/node_modules/*" \
\) | grep -vf ${WORKSPACE}/work/patchset.files | xargs -I{} rm {}

# Remove all the empty dirs remaining, but .git and work
find ${WORKSPACE} -depth -empty -type d -and -not \( -name .git -or -name work -or -name node_modules \) -delete

# ########## ########## ########## ##########

# Disable exit-on-error for the rest of the script, it will
# advance no matter of any check returning error. At the end
# we will decide based on gathered information
set +e

# Now run all the checks that only need the patchset affected files

if [ -f $WORKSPACE/.eslintrc ]; then
    echo "Info: Running eslint..."
    if ! ${npmcmd} list --depth=1 --parseable | grep -q eslint; then
        echo "Error: .eslintrc file found, but eslint package not found" | tee -a ${errorfile}
        exit 1
    fi

    # Run eslint
    # TODO: Remove this once everybody is using nodejs 14 or up.
    # We need to invoke eslint differently depending of the installed version.
    # (new versions v6.8 and up have this option to avoid exiting with error if there aren't JS files)
    eslintarg="--no-error-on-unmatched-pattern"
    # Old versions don't have this option, they exit without error if there aren't JS files, so don't use it.
    if ! npx eslint --help | grep -q -- $eslintarg; then
        eslintarg=""
    fi
    npx eslint -f checkstyle $eslintarg $WORKSPACE > "${WORKSPACE}/work/eslint.xml"
fi

if [ -f $WORKSPACE/.stylelintrc ]; then
    echo "Info: Running stylelint..."
    if ! ${npmcmd} list --depth=1 --parseable | grep -q stylelint; then
        echo "Error: .stylelintrc file found, but stylelint package not found" | tee -a ${errorfile}
        exit 1
    fi

    # Run stylelint
    # TODO: Remove this once everybody is using nodejs 14 or up.
    # We need to invoke stylelint differently depending of the installed version.
    # (new versions 7.7.0 and up have this option to avoid exiting with error if there aren't CSS files)
    stylelintarg="--allow-empty-input"
    # Old versions don't have this option, they exit without error if there aren't CSS files, so don't use it.
    if ! npx stylelint --help | grep -q -- $stylelintarg; then
        eslintarg=""
    fi
    if npx stylelint $stylelintarg --customFormatter 'node_modules/stylelint-checkstyle-formatter' "*/**/*.{css,less,scss}" > "${WORKSPACE}/work/stylelint.xml"
    then
        echo "Info: stylelint completed without errors."
    else
        # https://github.com/stylelint/stylelint/blob/main/docs/user-guide/cli.md#exit-codes
        stylelintcode=$?
        if [ $stylelintcode -eq 2 ]; then
            echo "Info: stylelint found errors in patchset."
        elif [ $stylelintcode -eq 80 ]; then
            echo "Info: No checkable CSS files detected in patchset."
            echo $emptycheckstyle > "${WORKSPACE}/work/stylelint.xml"
        else
            echo "Error: unexpected stylelint status '$stylelintcode'" | tee -a ${errorfile}
            exit 1
        fi
    fi
fi

# Don't need node stuff anymore, avoid it being analysed by any of the next tools.
rm -fr ${gitdir}/node_modules

# Run the upgrade savepoints checker, converting it to checkstyle format
# (it requires to be installed in the root of the dir being checked)
echo "Info: Running savepoints..."
cp ${mydir}/../check_upgrade_savepoints/check_upgrade_savepoints.php ${WORKSPACE}
${phpcmd} ${WORKSPACE}/check_upgrade_savepoints.php > "${WORKSPACE}/work/savepoints.txt"
cat "${WORKSPACE}/work/savepoints.txt" | ${phpcmd} ${mydir}/../check_upgrade_savepoints/savepoints2checkstyle.php > "${WORKSPACE}/work/savepoints.xml"
rm ${WORKSPACE}/check_upgrade_savepoints.php

# Note we have to pass the full list of components (valid_components.txt) as calculated
# earlier in the script when the whole code-base was available. Now, for performance
# reasons, only the patch-modified files are remaining so we cannot use phpcs abilities
# to detect all components anymore. Hence using the complete, already calculated, list.
# If we are checking a plugin, there are some differences in the checks performed.
# TODO: If https://github.com/moodlehq/moodle-cs/issues/92 becomes implemented, then
# we'll just have to change to the new, plugins specific, standard and forget.
declare -a phpcs_isplugin=()
if [[ -n "${isplugin}" ]]; then
    # Here we can exclude some checks or set runtime config values for the plugin checks.
    phpcs_isplugin=(
        "--runtime-set" "moodleTodoCommentRegex" ""
        "--runtime-set" "moodleLicenseRegex" ""
    )
fi
echo "Info: Running phpcs..."
${phpcmd} ${mydir}/../vendor/bin/phpcs \
    --runtime-set moodleComponentsListPath "${WORKSPACE}/work/valid_components.txt" \
    "${phpcs_isplugin[@]}" \
    --report=checkstyle --report-file="${WORKSPACE}/work/cs.xml" \
    --extensions=php --standard=moodle ${WORKSPACE}

if [[ -n "${LOCAL_CI_TESTS_RUNNING}" ]]; then
    # We don't run the moodlecheck tests in our testing environment because local_moodlecheck requires
    # a fully install Moodle. We don't want to requite that.
    # TODO: move to a more flexible way of excluding specific checks.
    echo $emptycheckstyle > "${WORKSPACE}/work/docs.xml"
else
    # Run the PHPDOCS (it runs from the CI installation, requires one moodle site installed!)
    # (we pass to it the list of valid components that was built before deleting files)
    echo "Info: Running phpdocs..."
    ${phpcmd} ${mydir}/../../moodlecheck/cli/moodlecheck.php \
        --path=${WORKSPACE} --format=xml --componentsfile="${WORKSPACE}/work/valid_components.txt" > "${WORKSPACE}/work/docs.xml"
fi

# ########## ########## ########## ##########

# It's time, at the end, to create the "overview" report with all the problems that this script
# has found and accumulated in the errors.txt file. That report will become part of the final
# reports (smurf files) generated and handled normally, like any other error or warning from
# the other checks executed above.

# Let's process the errors.txt file and convert it to checkstyle format.
echo "Info: Converting errors.txt to checkstyle format..."
${phpcmd} "${mydir}/checkstyle_converter.php" --format=errors < "${WORKSPACE}/work/errors.txt" > "${WORKSPACE}/work/errors.xml"

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

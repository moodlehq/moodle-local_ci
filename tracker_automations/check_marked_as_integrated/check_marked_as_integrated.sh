#!/usr/bin/env bash
#
# Checks fixVersion minors against major branches commits.
#
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#gitcmd: git cli path
#gitdir: git directory with integration.git repo
#gitremotename: integration.git remote name
#currentmaster: Deprecated, use devbranches instead. The final major version current master will be (e.g. 32).
#devbranches: the next major versions ($branch) under development, comma separated. Ordered by release "distance".
#             Since 3.10 (310) always use 3 digits. The last element in the list is assumed to be "master",
#             The rest are MOODLE_branch_STABLE ones. Normally only one, but when we are in parallel
#             development periods, for example: 310,400 (3.10 and 4.0)

# Let's go strict (exit on error)
set -e

if [ -z "$gitremotename" ]; then
    gitremotename="origin"
fi

# TODO: Remove these backward compatibility lines after some prudential time (say, in 2021).
if [ -z "$devbranches" ] && [ -n "$currentmaster" ]; then
    devbranches=$currentmaster
fi

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass gitcmd gitdir gitremotename devbranches"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# file where results will be sent
resultfile="$WORKSPACE/check_marked_as_integrated.csv"
echo -n > "${resultfile}"

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
IFS=',' read -a devbranchesarr <<< "$devbranches" # Convert devbranches to array.

# Include some utility functions
. "${mydir}/util.sh"

# Let's search for all the issues currently under integration.
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status IN ( \
                        'Waiting for testing', \
                        'Testing in progress', \
                        'Problem during testing', \
                        'Tested' \
                 ) \
                 AND 'Currently in integration' is not EMPTY" \
           --outputFormat "999" \
           --columns "Key,Fix Versions,Labels" \
           --file "${resultfile}"

# To store the errors and active branches.
errors=()
activebranches=()

# Move to the repo.
cd $gitdir

# Let's verify if a git gc is required.
${mydir}/../../git_garbage_collector/git_garbage_collector.sh

# Fetch stuff.
${gitcmd} fetch ${gitremotename}

# While looking at all the issues in integration, capture some variables to use
# for unowned commits check later.
# Pre-fill them with current development branches, note that last element is master, no MOODLE_branch_STABLE.
for devbranchcode in "${devbranchesarr[@]}"; do
    if [[ ${devbranchesarr[${#devbranchesarr[@]}-1]} != ${devbranchcode} ]]; then
        activebranches+=(MOODLE_${devbranchcode}_STABLE)
    else
        activebranches+=(master)
    fi
done
issues=() # The list of issues in current integration.
declare -A branchesbyissue # Associative array, issues as key, branches from fix versions
                           # in the tracker as value. Format: [MDL-123]=>MOODLE_311_STABLE, master

####
# Iterate over issues in integration and check their commits are integrated in the
# specified branches.
####
issueslist=$( cat "${resultfile}" )
while read -r line; do
    ismasteronly=
    issue=$( echo ${line} | sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' )
    issues+=($issue)

    if [[ -z ${issue} ]]; then
        # No issue found...
        continue
    fi

    echo "Processing ${issue}"

    if [[ $line == *"master-only"* ]]
    then
        ismasteronly=1
    fi

    fixversions=$( echo ${line} \
                    | sed -n "s/^\"MDL-[0-9]*\",\"\([^\"]*\)\".*/\1/p" \
                    | grep -o '[0-9]\+\.[0-9]\+\.\?[0-9]*' \
                  || echo '')

    if [[ -z ${fixversions} ]]; then
        # No fix versions found.
        errors+=("${issue} - No valid fix versions. Add 'skip-ci-version-check' label if this is expected.")
        continue
    fi

    devfound=0
    stablefound=0
    masterfixversionfound=
    branchesfromfixversion=
    while read -r tagversion; do

        # Strip quotes and minors.
        majorversion=$( echo ${tagversion} | grep -o "[0-9]\+\.[0-9]\+" )
        majorversion=${majorversion//.}
        # After 3.9 all branches are 3 digits, so we have to convert them (4.0 => 400, 4.1 => 401...)
        if [[ $majorversion -gt 39 ]]; then
            # Only if the version is 2 digit, because 3 digit ones (3.10 => 310...) are already correct.
            if [[ ${#majorversion} -eq 2 ]]; then
                majorversion=${majorversion:0:1}0${majorversion:1:1}
            fi
        fi

        if [[ ${devbranchesarr[@]} =~ $majorversion ]]; then
            devfound=$((devfound+1))
            # Last element corresponds to master, previous ones to MOODLE_branch_STABLE
            if [[ ${devbranchesarr[${#devbranchesarr[@]}-1]} == $majorversion ]]; then
                branchname=master
                masterfixversionfound=${tagversion}
            else
                branchname="MOODLE_${majorversion}_STABLE"
            fi
        else
            stablefound=$((stablefound+1))
            branchname="MOODLE_${majorversion}_STABLE"

            # Capture this as an active branch if not already added to the array.
            if ! [[ "${activebranches[@]}" =~ "${branchname}" ]]; then
                activebranches+=($branchname)
            fi
        fi

        branch="${gitremotename}/${branchname}"

        # Add the branch to the list of branches from fix versions.
        branchesfromfixversion+=${branchname},

        if ! check_issue "${gitcmd}" "${issue}" "${branch}"; then
            # No commit present in the repo since last roll.
            errors+=("${issue} - ${tagversion} marked as already integrated but no commit present in '${branch}'. Add 'skip-ci-version-check' label if this is expected.")
            continue
        fi

    done <<< "${fixversions}"

    # And, if master is missing... add it, we'll need it later.
    if [[ ! ${branchesfromfixversion} =~ master ]]; then
        branchesfromfixversion+=master
    fi
    # Add the branches from the tracker fix versions to the branchesbyissue associative array.
    branchesbyissue[${issue}]=${branchesfromfixversion}

    if [[ $line == *"skip-ci-version-check"* ]]
    then
        echo "Skipping ${issue} - is marked with skip-ci-version-check"
        continue
    fi

    # If we haven't checked all dev branches (we don't add dev versions to fixVersion) we
    # check it here. May report false positives, but normally everything going to stables
    # must go also to ALL dev branches (unless the skip-ci-version-check is used for the issue).
    # Only allowed exception is when an issue only has master commits and the "master-only" label.
    if [ $devfound -lt ${#devbranchesarr[@]} ]; then
        examiningmaster=
        for devbranchcode in "${devbranchesarr[@]}"; do
            if [[ ${devbranchesarr[${#devbranchesarr[@]}-1]} != ${devbranchcode} ]]; then
                branch=${gitremotename}/MOODLE_${devbranchcode}_STABLE
                examiningmaster=
            else
                branch=${gitremotename}/master
                examiningmaster=1
            fi

            # If the commit doesn't exits...
            if ! check_issue "${gitcmd}" "${issue}" "${branch}"; then
                # Only allowed exception is having the master-only label when examining non-master branches
                if [[ -n "$ismasteronly" ]] && [[ -z "$examiningmaster" ]]; then
                    echo "  - has the "master-only" label, not looking for "${branch}" commits."
                else
                    # If no master-only label and missing commit is not in master, personalize the error about that.
                    if [[ -z "$ismasteronly" ]] && [[ -z "$examiningmaster" ]]; then
                        errors+=("${issue} - no commit present in ${branch}. Maybe correct and the issue is 'master-only' ? Add the label if that's the case.")
                    else
                        errors+=("${issue} - no commit present in ${branch}. Add 'skip-ci-version-check' label if this is expected.")
                    fi
                fi

            # If the commit exists...
            else
                # If the issue has the master-only label and we have found commits in non-master dev branches, something is wrong.
                if [[ -n "$ismasteronly" ]] && [[ -z "$examiningmaster" ]]; then
                    errors+=("${issue} - commit found in ${branch}. Check if the 'master-only' label in the issue is correct.")
                fi
            fi
        done
    fi

    # If we have devfound together with stablefound, the fix versions are not correct
    # (fix versions must be stables or one dev, never both together). Report it.
    if [ $devfound -gt 0 ] && [ $stablefound -gt 0 ]; then
        errors+=("${issue} - cannot mix stables and dev fix versions in the Tracker. Please solve that.")
    fi

    # If there are multiple devfound that's incorrect too, only one (the 1st) must be set.
    if [ $devfound -gt 1 ]; then
        errors+=("${issue} - cannot set multiple dev fix versions in the Tracker (earliest to be released wins). Please solve that.")
    fi

    # Under parallel development only, if has master as fix version, then it must have the "master-only" branch.
    if [ ${#devbranchesarr[@]} -gt 1 ]; then
        if [[ -n "$masterfixversionfound" ]] && [[ -z "$ismasteronly" ]]; then
            errors+=("${issue} - cannot use the master ($masterfixversionfound) fix version without setting the "master-only" label.")
        fi
    fi

done <<< "${issueslist}"

####
# Now for any commits which are not found in current integration..
####

# Hacky 'join' from bash array into extended grep syntax string i.e.(MDL-3333|MDL-4444|MDL-12345)
allissues=${issues[*]}
grepsearch="(${allissues// /|}|^Automatically generated|^weekly.*release|^Moodle release|^on\-demand|^NOBUG\:|This reverts commit)"

# No issues, no active branches to check yet (so the next 2 loops won't happen)
if [[ ${#issues[@]} -eq 0 ]]; then
    activebranches=()
fi

# Loop through the active branches looking for commits without issues in integration
for branch in "${activebranches[@]}"
do
    echo "Looking for unowned commits in $branch"
    # Verify the branch exists.
    if [[ -z $($gitcmd ls-remote --heads git://git.moodle.org/moodle.git ${branch#"origin/"}) ]]; then
        echo "  WARNING: moodle.git ${branch#"origin/"} fetching problems, cannot look for commits. Please check if that's correct."
        continue
    fi
    # Fetch the equivalent moodle.git branch
    $gitcmd fetch -q git://git.moodle.org/moodle.git $branch
    # Find unowned commits since moodle.git
    unownedcommits=$($gitcmd log origin/${branch}...FETCH_HEAD \
        --pretty=format:"  %h %s (%an)" --no-merges \
        --invert-grep --extended-regexp --regexp-ignore-case \
        --grep="$grepsearch")

    # If we find unowned commits report them.
    if [[ $unownedcommits ]]; then
        errors+=("$branch commits found without issue in integration:" "$unownedcommits")
    fi
done

# Loop through the active branches verifying that their commits match the fix-versions in the tracker.
for branch in "${activebranches[@]}"
do
    echo "Looking for $branch issues and matching against tracker fix versions"
    # Fetch the equivalent moodle.git branch
    $gitcmd fetch -q git://git.moodle.org/moodle.git $branch
    # Look for all the issues having commits in the branch.
    foundissues=$($gitcmd log origin/${branch}...FETCH_HEAD \
        --pretty=format:"%s" --no-merges \
        --extended-regexp --regexp-ignore-case \
        --grep="$grepsearch" | cut -d' ' -f1 | sort | uniq)
    while read -r issue; do
        # Get the list of tracker expectations (fix-versions) for the issue.
        fixbranches=${branchesbyissue[${issue}]}
        # Ignore, unowned commits above already should have detected this.
        if [[ -z ${fixbranches} ]]; then
            continue
        fi
        # Now ensure that the branch being tested is in the list of fixed branches coming from tracker.
        if [[ ! ${fixbranches} =~ ${branch} ]]; then
            errors+=("${issue} has commits in $branch but missed that fix-version in tracker")
        fi

    done <<< "${foundissues}"
done

echo

####
# Report errors if necessary
####
if [ ! -z "$errors" ]; then
    echo "Errors found:"
    printf '%s\n' "${errors[@]}"
    exit 1
fi

# Remove the resultfile. We don't want to disclose those details.
rm -f "${resultfile}"

echo "All good"
exit 0

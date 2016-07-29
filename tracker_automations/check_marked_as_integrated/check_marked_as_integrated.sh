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
#currentmaster: the final major version current master will be (e.g. 32)

# Let's go strict (exit on error)
set -e

if [ -z "$gitremotename" ]; then
    gitremotename="origin"
fi

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass gitcmd gitdir gitremotename currentmaster"
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

# Include some utility functions
. "${mydir}/util.sh"

# Let's search all the issues having the "ci" label that have been sent back
# to development (form peer review or integration)
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status IN ( \
                        'Waiting for testing', \
                        'Testing in progress', \
                        'Problem during testing', \
                        'Tested' \
                 ) \
                 AND 'Currently in integration' is not EMPTY \
                 AND labels not in ('skip-ci-version-check')" \
           --outputFormat "999" \
           --columns "Key,Fix Versions" \
           --file "${resultfile}"

# To store the errors.
errors=()

# Move to the repo.
cd $gitdir

# Let's verify if a git gc is required.
${mydir}/../../git_garbage_collector/git_garbage_collector.sh

# Fetch stuff.
${gitcmd} fetch ${gitremotename}

# While looking at all the issues in integration, capture some variables to use
# for unowned commits check later.
activebranches=(master) # The active branches which we have commits on.
issues=() # The list of issues in current integration.

####
# Iterate over issues in integration and check their commits are integrated in the
# specified branches.
####
issueslist=$( cat "${resultfile}" )
while read -r line; do
    issue=$( echo ${line} | sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' )
    issues+=($issue)

    if [[ -z ${issue} ]]; then
        # No issue found...
        continue
    fi

    echo "Processing ${issue}"

    fixversions=$( echo ${line} \
                    | sed -n "s/^\"MDL-[0-9]*\",\"\(.*\)\"/\1/p" \
                    | grep -o '[0-9]\+\.[0-9]\+\.\?[0-9]*' \
                  || echo '')

    if [[ -z ${fixversions} ]]; then
        # No fix versions found.
        errors+=("${issue} - No valid fix versions. Add 'skip-ci-version-check' label if this is expected.")
        continue
    fi

    masterfound=
    while read -r tagversion; do

        # Strip quotes and minors.
        majorversion=$( echo ${tagversion} | grep -o "[0-9]\+\.[0-9]\+" )
        majorversion=${majorversion//.}

        if [[ "$majorversion" == "$currentmaster" ]]; then
            branch=$gitremotename'/master'
            masterfound=1
        else
            branchname="MOODLE_${majorversion}_STABLE"
            branch="${gitremotename}/${branchname}"

            # Capture this as an active branch if not already added to the array.
            if ! [[ "${activebranches[@]}" =~ "${branchname}" ]]; then
                activebranches+=($branchname)
            fi
        fi

        if ! check_issue "${gitcmd}" "${issue}" "${branch}"; then
            # No commit present in the repo.
            errors+=("${issue} - ${tagversion} marked as fixed but no commit present in '${branch}'. Add 'skip-ci-version-check' label if this is expected.")
            continue
        fi

    done <<< "${fixversions}"

    # If we haven't checked master (we don't mark next major in fixVersion) we
    # check it here. May report false positives.
    if [ -z "$masterfound" ]; then
        branch=$gitremotename'/master'
        if ! check_issue "${gitcmd}" "${issue}" "${branch}"; then
            # No commit present in the repo.
            errors+=("${issue} - no commit present in master. Add 'skip-ci-version-check' label if this is expected.")
        fi
    fi

done <<< "${issueslist}"

####
# Now for any commits which are not found in current integration..
####

# Hacky 'join' from bash array into extended grep syntax string i.e.(MDL-3333|MDL-4444|MDL-12345)
allissues=${issues[*]}
grepsearch="(${allissues// /|}|^Automatically generated|^weekly.*release|^Moodle release|^on\-demand|^NOBUG\:|This reverts commit|)"

# Loop through the active branches looking for commits without issues in integration
for branch in "${activebranches[@]}"
do
    echo "Looking for unowned commits in $branch"
    # Fetch the equivalent moodle.git branch
    $gitcmd fetch -q git://git.moodle.org/moodle.git $branch
    # Find unowned commits since moodle.git
    unownedcommits=$($gitcmd log origin/${branch}...FETCH_HEAD \
        --pretty=format:"  %h %s (%an)" --no-merges \
        --invert-grep --extended-regexp \
        --grep="$grepsearch")

    # If we find unowned commits report them.
    if [[ $unownedcommits ]]; then
        errors+=("$branch commits found without issue in integration:" "$unownedcommits")
    fi
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

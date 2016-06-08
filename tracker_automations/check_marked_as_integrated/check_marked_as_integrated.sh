#!/bin/bash
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
${gitcmd} fetch ${gitremotename}

# Iterate over found issues and check that their commits are integrated in the
# specified branches.
issueslist=$( cat "${resultfile}" )
while read -r line; do
    issue=$( echo ${line} | sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' )

    if [[ -z ${issue} ]]; then
        # No issue found...
        continue
    fi

    echo "Processing ${issue}"

    fixversions=$( echo ${line} \
                    | sed -n "s/^\"MDL-[0-9]*\",\"\(.*\)\"/\1/p" \
                    | grep -o '[0-9]\+\.[0-9]\+\.\?[0-9]*'
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
            branch=$gitremotename'/MOODLE_'$majorversion'_STABLE'
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

if [ ! -z "$errors" ]; then
    printf '%s\n' "${errors[@]}"
    exit 1
fi

# Remove the resultfile. We don't want to disclose those details.
rm -f "${resultfile}"

echo "All good"
exit 0

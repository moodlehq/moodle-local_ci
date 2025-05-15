#!/usr/bin/env bash
# Look all reopened or under development issues and remove the ci label from them.
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load Jira Configuration.
source "${mydir}/../../jira.sh"

# file where results will be sent
resultfile=$WORKSPACE/remove_ci_label_from_wip.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/remove_ci_label_from_wip.log

# Calculate some variables
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the reopenend issues within jenkins ($logfile)

# Let's search all the issues having the "ci" label that have been sent back to development (form peer review or integration)
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND labels IN ('ci') \
                 AND status IN ('Development in progress', 'Reopened')" \
           --file "${resultfile}"

# Iterate over found issues and remove the "ci" label from them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action removeLabels \
        --issue ${issue} \
         --labels "ci"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

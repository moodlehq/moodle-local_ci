#!/usr/bin/env bash
# Look for issues known to need their integration priority raised.
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#mustfixversion: textual "must fix for X.Y" version to raise integration priority to 1.

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass mustfixversion"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# file where results will be sent
resultfile=$WORKSPACE/set_integration_priority_to_one.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/set_integration_priority_to_one.log

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the reopenend issues within jenkins ($logfile)

# Let's search all the issues in Moodle project having zero integration priority and
# being under current integration or awaiting integration. Raise integration priority
# for those having the mdlqa label or a given mustfixversion.
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND 'Integration priority' = 0 \
                 AND ( \
                       'Currently in integration' = 'Yes' \
                       OR status = 'Waiting for integration review' \
                     ) \
                 AND ( \
                       labels IN (mdlqa)
                       OR fixVersion = '${mustfixversion}' \
                       OR level IS NOT EMPTY \
                     )" \
           --file "${resultfile}"

# Iterate over found issues and set their integration priority (customfield_12210) to 1.
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action progressIssue \
        --issue ${issue} \
        --step "CI Global Self-Transition" \
        --custom "customfield_12210:1"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

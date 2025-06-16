#!/usr/bin/env bash
# Look all reopened issues under current integration and move them out
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#mustfixversion: fixfor version which will be preserved on reopening

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE mustfixversion"
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
resultfile=$WORKSPACE/mv_reopened_out_from_current.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/mv_reopened_out_from_current.log

# Calculate some variables
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the reopenend issues within jenkins ($logfile)

# Let's search all the reopened issues under current integration, not updated in 1h
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND status = 'Reopened' \
                 AND updated < '-1h' \
                 AND 'Currently in integration' is not empty" \
           --outputFormat "999" \
           --columns "Key,Fix Versions" \
           --file "${resultfile}"

# Iterate over found issues and send them out from integration with a comment
while read line; do
    issue=$( echo ${line} | sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' )
    keepversion=
    if [[ -z ${issue} ]]; then
        # No issue found... skip.
        continue
    fi
    echo "Processing ${issue}"
    # If the issue has the specified mustfixversion... let's keep it on reopen
    if [[ -n ${mustfixversion} ]]; then
        # Look for mustfixversion match
        keepversion=$( echo ${line} | sed -n "s/^\"MDL-[0-9]*\",\".*\(${mustfixversion}\).*/\1/p" )
        if [[ -z ${keepversion} ]]; then
            echo "  - No mustfix version to keep"
        else
            echo "  - Keeping mustfix version \"${keepversion}\""
        fi
    fi
    # For fields available in the default screen, it's ok to use updateIssue or SetField, but in this case
    # we are setting some custom fields not available (on purpose) on that screen. So we have created a
    # global transition, only available to the bots, not transitioning but bringing access to all the fields
    # via special screen. So we'll ne using that global transition via transitionIssue instead.
    # Also, there is one bug in the 4.4.x series, setting the destination as 0, leading to error in the
    # execution, so the form was hacked in the browser to store correct -1: https://jira.atlassian.com/browse/JRA-25002
    # Commented below, it's the "ideal" code. If some day JIRA changes that restriction we could stop using
    # that non-transitional transition and use normal update.
    #${basereq} --action updateIssue \
    #    --issue ${issue} \
    #    --field "${customfield_currentlyInIntegration}"= \
    #    --comment "Moving this reopened issue out from current integration. Please, re-submit it for integration once ready."
    #
    ${basereq} --action transitionIssue \
        --issue ${issue} \
        --transition "CI Global Self-Transition" \
        --fixVersions "${keepversion}" \
        --field "${customfield_currentlyInIntegration}"= \
        --field "${customfield_automatedTestResults}"= \
        --comment "Moving this reopened issue out from current integration. Please, re-submit it for integration once ready."
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
done < "${resultfile}"

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

#!/usr/bin/env bash
# Look all issues under current integration, still awaiting for integration, officially delaying them by:
#   - current in integration: empty (no)
#   - integration priority: 1
#   - comment: fixed text (acepting optional alternative content)
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#altcomment: in case a custom comment wants to be used (defaults to standard, fixed one)

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
resultfile=$WORKSPACE/delay_awaiting_issues.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/delay_awaiting_issues.log

# Calculate some variables
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Set comment if not specified
altcomment=${altcomment:-"The integration of this issue has been delayed until next week because the integration period is over (Mondays to Thursday 12:00 UTC+8) and testing must happen with code established.

This rigid timeframe on each integration/testing cycle aims to produce a better and clear separation and organization of tasks for everybody.

This is a bulk-automated message, so if you want to blame somebody/thing/where don't do it here (use git instead) :-D :-P

Apologies for the inconvenience, this might be integrated next week. Thanks for your collaboration & ciao :-)"}

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the closed issues within jenkins ($logfile)

# Let's search all the tested issues under current integration.
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                AND status = 'Waiting for integration review' \
                AND 'Currently in integration' IS NOT EMPTY" \
           --file "${resultfile}"

# Iterate over found issues and perform the actions with them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    # We use transitionIssue instead of updateIssue because some of the fileds are not available in the default screen.
    # (current in integration = customfield_XXXXX, integration priority = customfield_XXXXX)
    ${basereq} --action transitionIssue \
        --issue ${issue} \
        --transition "CI Global Self-Transition" \
        --field "${customfield_currentlyInIntegration}"= \
        --field "${customfield_integrationPriority}"=1 \
        --comment "${altcomment}"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

#!/usr/bin/env bash
# Look all issues awaiting integration and move them to current integration by:
#   - clean the integrator field
#   - clean the integration date
#   - check the "current in integration" flag.
#   - add a comment about the move.
#   - delete the "ci" label.
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# file where results will be sent
resultfile=$WORKSPACE/move_to_current_integration.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/move_to_current_integration.log

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the reopenend issues within jenkins ($logfile)

# Let's search all the issues having the "ci" label that have been sent back to development (form peer review or integration)
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND status = 'Waiting for integration review' \
                 AND 'Currently in integration' IS EMPTY \
                 AND (labels IS EMPTY OR labels NOT IN (integration_held, security_held))" \
           --file "${resultfile}"

# Iterate over found issues and perform the actions with them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    # For fields available in the default screen, it's ok to use updateIssue or SetField, but in this case
    # we are setting some custom fields not available (on purpose) on that screen. So we have created a
    # global transition, only available to the bots, not transitioning but bringing access to all the fields
    # via special screen. So we'll ne using that global transition via progressIssue instead.
    # Also, there is one bug in the 4.4.x series, setting the destination as 0, leading to error in the
    # execution, so the form was hacked in the browser to store correct -1: https://jira.atlassian.com/browse/JRA-25002
    # Commented below, it's the "ideal" code. If some day JIRA changes that restriction we could stop using
    # that non-transitional transition and use normal update.
    #${basereq} --action updateIssue \
    #    --issue ${issue} \
    #    --custom "customfield_10110:,customfield_10210:,customfield_10211:Yes"
    ${basereq} --action progressIssue \
        --issue ${issue} \
        --step "CI Global Self-Transition" \
        --custom "customfield_10110:,customfield_10210:,customfield_10211:Yes,customfield_15810:No,customfield_10011:" \
        --comment "Moving this issue to current integration cycle, will be reviewed soon. Thanks for the hard work!"
    ${basereq} --action removeLabels \
        --issue ${issue} \
        --labels "ci"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

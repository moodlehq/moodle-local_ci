#!/usr/bin/env bash
# Manage issues waiting for feedback (WfF), both IR and CLR ones.
# This job is in charge of performing the following options:
# A) Initial: When an issue is sent to "Waiting for feedback" add
#    a comment explaining that the developer has X days to
#    provide the needed information/changes and send the issue
#    back to review.
# B) Reopen: After X days under the "Waiting for feedback" status,
#    proceed to reopen the issue.
# C) Remind (optional): After Y days (Y<X) add a comment with a
#    friendly reminder to the developer explaining that the
#    issue will be reopen in X-Y days.
# Note that, in order to make the queries and this job easier,
# we use the " "Waiting for Feedback Notifications" custom field
# to know in which of the A-B-C phases we exactly are and which
# notifications have been already sent.
# For details, see https://tracker.moodle.org/browse/MDLSITE-6612
#jiraclicmd: fill execution path of the jira cli.
#jiraserver: jira server url we are going to connect to.
#jirauser: user that will perform the execution.
#jirapass: password of the user.
#daystoreopen: number of days to proceed to reopen the issue since the issue was sent to WfF.
#daystoremind: number of days to proceed to remind about the incoming reopen since the issue was sent to WfF. Default 0 = disabled.

# Let's go strict (exit on error).
set -e

# Verify everything is set.
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass daystoreopen"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# File where tracker results will be sent.
resultfile=$WORKSPACE/manage_waiting_for_feedback.csv
echo -n > "${resultfile}"

# File where updated entries will be logged.
logfile=$WORKSPACE/manage_waiting_for_feedback.log

# Calculate some variables.
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Set defaults.
daystoremind=${daystoremind:-0}

# Verify that daystoreopen is integer and > 0.
if [[ ! $daystoreopen =~ ^[0-9]+$ ]] || [[ ! $daystoreopen -gt 0 ]]; then
    echo "Error. \$daystoreopen ($daystoreopen) needs to be valid, greater than zero, integer."
    exit 1
fi

# Verify that daystoremind is integrer and >= 0.
if [[ ! $daystoremind =~ ^[0-9]+$ ]]; then
    echo "Error. \$daystoremind ($daystoremind) needs to be valid, greater than or equal to zero,integer."
    exit 1
fi

# Verify that daystoremind < daystoreopen.
if [[ ! $daystoremind -lt $daystoreopen ]]; then
    echo "Error. \$daystoremind ($daystoremind) needs to be less than \$daystoreopen ($daystoreopen)."
    exit 1
fi

# We need to use hours instead of days, because the "AFTER -5d" is not accurate enough. In
# practice it accounts for 4.5 days, or something like that, hence the actions are happening
# some hours before they should. So, using hours (days * 24) to get more accurate results.
hourstoreopen=$((24*$daystoreopen))
hourstoremind=$((24*$daystoremind))

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the reopenend issues within jenkins ($logfile)

# A) Let's add a comment explaining how the "Waiting for feedback" status works.
#    - Do it for all the issues in the status having "Waiting for Feedback Notifications" = 1
#    - And, once done, set the "Waiting for Feedback Notifications" field to 2.
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND status IN ('Waiting for feedback', 'Waiting for feedback (CLR)') \
                 AND 'Waiting for Feedback Notifications' = 1" \
           --file "${resultfile}"

# Iterate over found issues, adding the comment and setting 'Waiting for Feedback Notifications' to 2.
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue} - Initial notification"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}: Initial notification" >> "${logfile}"
    # For fields available in the default screen, it's ok to use updateIssue or setFieldValue, but in this case
    # we are setting some custom fields not available (on purpose) on that screen. So we have created a
    # global transition, only available to the bots, not transitioning but bringing access to all the fields
    # via special screen. So we'll be using that global transition via transitionIssue instead.
    # Commented below, it's the "ideal" code. If some day JIRA changes that restriction we could stop using
    # that non-transitional transition and use normal update.
    # (Note: Versions 6.6 and 8.8 continue having the restriction)
    #${basereq} --action setFieldValue \
    #           --issue  ${issue} \
    #           --field  'Waiting for Feedback Notifications' \
    #           --value  1
    comment="The integrator needs more information or changes from your patch in order to progress this issue. Please provide your response within ${daystoreopen} days and press \"Feedback provided\" once done. Otherwise, the issue will be reopened automatically to give you more time to address the points mentioned by the integrator."
    ${basereq} --action transitionIssue \
               --issue ${issue} \
               --transition "CI Global Self-Transition" \
               --field  'Waiting for Feedback Notifications' \
               --value  2 \
               --comment "${comment}"
done

# B) Let's reopen the issue with a comment.
#    - Do it for all the issues in the status having "Waiting for Feedback Notifications" = 2 or 3
#      that have spent more than ${hourstoreopen} awaiting for feedback.
#    - Note that the transition, automatically, will clear the "Waiting for Feedback Notifications"
#      field. It has been defined in the Workflow as a post action.
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND status IN ('Waiting for feedback', 'Waiting for feedback (CLR)') \
                 AND NOT status CHANGED AFTER -${hourstoreopen}h \
                 AND 'Waiting for Feedback Notifications' IN (2,3)" \
           --file "${resultfile}"

# Iterate over found issues, adding the comment ('Waiting for Feedback Notifications' will be cleaned by the workflow).
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue} - Reopen notification"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}: Reopen notification" >> "${logfile}"
    comment="This issue has been waiting for feedback over the last ${daystoreopen} days and has been reopened automatically. Please address any remaining point and send it back to peer-review."
    ${basereq} --action transitionIssue \
               --issue ${issue} \
               --transition "Reopen Issue" \
               --comment "${comment}"
done

# C) Let's remind in the issue with a comment, only if ${hourstoremind} > 0.
#    - Do it for all the issues in the status having "Waiting for Feedback Notifications" = 2
#      that have spent more than ${hourstoremind} awaiting for feedback.
#    - And, once done, set the "Waiting for Feedback Notifications" field to 3.
if [[ ${hourstoremind} -gt 0 ]]; then
    ${basereq} --action getIssueList \
               --jql "project = 'Moodle' \
                     AND status IN ('Waiting for feedback', 'Waiting for feedback (CLR)') \
                     AND NOT status CHANGED AFTER -${hourstoremind}h \
                     AND 'Waiting for Feedback Notifications' = 2" \
               --file "${resultfile}"

    # Iterate over found issues, adding the comment and setting 'Waiting for Feedback Notifications' to 3.
    for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        echo "Processing ${issue} - Reminder notification"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}: Reminder notification" >> "${logfile}"
        daysremaining=$(($daystoreopen-$daystoremind))
        comment="Note that this issue has been waiting for feedback over the last ${daystoremind} days and will be automatically reopened in ${daysremaining} days. Please provide your response before then and press \"Feedback provided\" once done."
        # Again, we have to use the 'CI Global Self-Transition' to be able to update the
        # 'Waiting for Feedback Notifications' hidden field.
        ${basereq} --action transitionIssue \
                   --issue ${issue} \
                   --transition "CI Global Self-Transition" \
                   --field  'Waiting for Feedback Notifications' \
                   --value  3 \
                   --comment "${comment}"
    done
fi

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

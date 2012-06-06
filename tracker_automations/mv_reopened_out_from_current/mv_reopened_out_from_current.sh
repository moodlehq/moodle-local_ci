#!/bin/bash
# Look all reopened issues under current integration and move them out
#jiraclicmd: fill execution path of the jira cli
#jirasever: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user

# Let's go strict (exit on error)
set -e

# file where results will be sent
resultfile=$WORKSPACE/mv_reopened_out_from_current.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/mv_reopened_out_from_current.log

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jirasever} --user ${jirauser} --password "

# Let's connect to the tracker and get session token
token="$( ${basereq} ${jirapass} --action login )"

# Calculate the basereq including token for subsequent calls
basereq="${basereq} lalala --login ${token} "

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the reopenend issues within jenkins ($logfile)

# Let's search all the reopened issues under current integration, not updated in 8h
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Reopened' \
                 AND updated < '-8h' \
                 AND 'Currently in integration' is not empty" \
           --file "${resultfile}"

# Iterate over found issues and send them out from integration with a comment
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action updateIssue \
               --issue ${issue} \
               --custom "customfield_10211:" \
               --comment "Moving this reopened issue out from current integration. Please, re-submit it for integration once ready."
    echo "$BUILD_NUMBER $BUILD_ID ${issue}" >> "${logfile}"
done

# Let's disconnect
echo "$( ${basereq} --action logout )"

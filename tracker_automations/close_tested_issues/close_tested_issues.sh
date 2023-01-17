#!/usr/bin/env bash
# Look all issues tested and transition them to closed:
#   - status: closed
#   - resolution: fixed
#   - current in integration: empty (no)
#   - integration date: YYYY-MM-DD (accepting optional date, defaults to today)
#   - comment: fixed text (acepting optional alternative content)
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#altdate: date to close the issues with (defaults to today)
#altcomment: in case a custom comment wants to be used (defaults to standard, fixed one)

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
resultfile=$WORKSPACE/close_tested_issues.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/close_tested_issues.log

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Set closedate and closecomment if not specified
altdate=${altdate:-$(date -I)}
altcomment=${altcomment:-"Thanks for your contributions! This change is now available from the main moodle.git repository and will shortly be available on download.moodle.org.

Closing as fixed!"}

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the closed issues within jenkins ($logfile)

# Let's search all the tested issues under current integration.
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND status = 'Tested' \
                 AND 'Currently in integration' IS NOT EMPTY" \
           --file "${resultfile}"

# Iterate over found issues and perform the actions with them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action transitionIssue \
        --issue ${issue} \
        --transition "Mark as committed" \
        --resolution "Fixed" \
        --field "customfield_10211=" \
        --field "customfield_10210=${altdate}" \
        --comment "${altcomment}"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

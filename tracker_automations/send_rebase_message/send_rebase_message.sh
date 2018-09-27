#!/usr/bin/env bash
# Look all issues awaiting for integration (not in current)
# and send them the std. rebase message.
# In the future we can send the message selectively
# (if there are conflicts...). See MDLSITE-3702 for moe info.
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
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
resultfile=$WORKSPACE/send_rebase_message.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/send_rebase_message.log

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Set altcomment if not specified
altcomment=${altcomment:-"The main moodle.git repository has just been updated with latest weekly modifications. You may wish to rebase your PULL branches to simplify history and avoid any possible merge conflicts. This would also make integrator's life easier next week.

TIA and ciao :-)"}

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the closed issues within jenkins ($logfile)

# Let's search all the tested issues under current integration.
${basereq} --action getIssueList \
           --search "filter = 14000" \
           --file "${resultfile}"

# Iterate over found issues and perform the actions with them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action addComment \
        --issue ${issue} \
        --comment "${altcomment}"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

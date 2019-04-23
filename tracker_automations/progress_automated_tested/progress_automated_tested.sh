#!/usr/bin/env bash
# 1) Look for all issues under current integration, which tester is cibot or nobody
#    and are waiting for testing. Move them to testing in progress. Without comment.
# 2) Look for all issues under current integration, which tester is cibot or nobody
#    and are testing in progress since 24h ago. Move them to tested. With comment.
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
resultfile=$WORKSPACE/progress_automated_testing.txt
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/progress_automated_waiting_testing.log

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Let's search 1a) Waiting for testing => Testing in progress (via Start testing)
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Waiting for testing' \
                 AND 'Currently in integration' IS NOT EMPTY \
                 AND Tester IN (cibot, nobody)" \
           --file "${resultfile}"

# Iterate over found issues and perform the actions with them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action transitionIssue \
        --issue ${issue} \
        --transition "Start testing"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP waiting2progress ${issue}" >> "${logfile}"
done

# Reset the results file
echo -n > "${resultfile}"

# Let's search 1b) Waiting for security testing => Security testing in progress (via Start security testing)
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Waiting for security testing' \
                 AND 'Currently in integration' IS NOT EMPTY \
                 AND Tester IN (cibot, nobody)" \
           --file "${resultfile}"

# Iterate over found issues and perform the actions with them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action transitionIssue \
        --issue ${issue} \
        --transition "Start security testing"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP waiting2progress_security ${issue}" >> "${logfile}"
done

# Reset the results file
echo -n > "${resultfile}"

# Let's search 2a) Testing in progress => Tested (via Testing passed)
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Testing in progress' \
                 AND 'Currently in integration' IS NOT EMPTY \
                 AND Tester IN (cibot, nobody) \
                 AND NOT status changed AFTER -24h" \
           --file "${resultfile}"

# Iterate over found issues and perform the actions with them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action transitionIssue \
        --issue ${issue} \
        --transition "Testing passed" \
        --comment "Testing passed after 24h without any problem reported, yay! Issue will now wait for next minor/security release."
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP progress2tested ${issue}" >> "${logfile}"
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

# Let's search 2b) Security testing in progress => Waiting for release (via Security testing passed)
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Security testing in progress' \
                 AND 'Currently in integration' IS NOT EMPTY \
                 AND Tester IN (cibot, nobody) \
                 AND NOT status changed AFTER -24h" \
           --file "${resultfile}"

# Iterate over found issues and perform the actions with them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action transitionIssue \
        --issue ${issue} \
        --transition "Security testing passed" \
        --comment "Testing passed after 24h without any problem reported, yay!"
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP progress2tested_security ${issue}" >> "${logfile}"
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

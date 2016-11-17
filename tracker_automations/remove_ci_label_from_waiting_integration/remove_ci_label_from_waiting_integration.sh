#!/usr/bin/env bash
# Look for all the issues awaiting integration that were not awaiting integration the last time
# the job was executed and having the "ci label in order to remove it and get prechecker performed.
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
resultfile=$WORKSPACE/remove_ci_label_from_waiting_integration.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/remove_ci_label_from_waiting_integration.log
lastfile=$WORKSPACE/remove_ci_label_from_waiting_integration_latest.log

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
now=$(date +%s)

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the reopenend issues within jenkins ($logfile)

# Let's search all the issues having the "ci" label that have landed to integration along the last hour
# but are not under current integration.
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND labels IN ('ci') \
                 AND labels NOT IN (integration_held, security_held) \
                 AND status = 'Waiting for integration review' \
                 AND 'Currently in integration' IS EMPTY \
                 AND status CHANGED AFTER '-60m' " \
           --file "${resultfile}"

# Iterate over found issues and remove the "ci" label from them
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    # Verify the issue has not been processed in the last 60 minutes (local time).
    canremovelabel=1
    if [[ -r "${lastfile}" ]]; then
        linefound=$(grep "${issue}" "${lastfile}" | tail -1)
        if [[ -n $linefound ]]; then
            timefound="${linefound##* }"
            secondsago=$(($now - $timefound))
            echo "    - 'ci' label was removed $secondsago ago"
            if [[ $secondsago -le 3600 ]]; then
                echo "    - skipping, that's less than 1 hour ago"
                canremovelabel=
            fi
        fi
    fi
    if [[ -n $canremovelabel ]]; then
        ${basereq} --action removeLabels \
           --issue ${issue} \
           --labels "ci"
        echo ${issue} $(date +%s) >> "${lastfile}"
        echo "    - 'ci' label removed"
    fi
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
done

# Auto-clean the lastfile when possible. If the last entry in the file
# is older than 1 hour, it can be safely deleted because not entry in
# it will match the conditions above anymore.
if [[ -r "${lastfile}" ]]; then
    lastline=$(tail -1 "${lastfile}")
    lasttime="${lastline##* }"
    secondsago=$(($now - $lasttime))
    if [[ $secondsago -gt 3600 ]]; then
        rm -fr "${lastfile}"
        echo "Cleaning outdated latest results"
    else
        echo "Keeping meaningful latest results"
    fi
fi

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

#!/usr/bin/env bash
# Looks for all undecided issues awaiting integration and decides about sending them
# to Component Leads Review (clr) or Integration Review (ir).
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#jsonclrurl: url to the webservice providing all the groups, components and reviewers data.
#clearcache: set it to "true" to force the removal of the (48h) cached groups, components and reviewers data.
#quiet: with any value different from "false", don't perform any action in the Tracker.
#restrictedto: if set, restrict any comment to that role in the project. Blank means visible to everybody.

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass jsonclrurl"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# We need curl to execute this script.
if [[ ! $(which curl) ]]; then
    echo "Error: This script needs \"curl\" installed to work"
    exit 1
fi

# We need jq to execute this script.
if [[ ! $(which jq) ]]; then
    echo "Error: This script needs \"jq\" installed to work"
    exit 1
fi

# file where results will be sent
resultfile=${WORKSPACE}/component_leads_integration_mover.json
echo -n > "${resultfile}"

# file where actions peformed will be logged
logfile=${WORKSPACE}/component_leads_integration_mover.log

# file where the components, groups and CLRs will be stored.
clrfile=${WORKSPACE}/clr.json

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

if [[ "${clearcache}" == "true" ]]; then
    echo "CLR metadata cache deleted."
    rm -fr ${clrfile}
fi

# If we don't have the clr.json information at hand, let's download it.
if [[ ! -r "${clrfile}" ]]; then
    echo "Downloading the CLR metadadata information."
    if ! curl -sL -o ${clrfile} $jsonclrurl; then
        echo "Problem downloading the initial CLR metadata information."
        rm -f ${clrfile}
        exit 1
    fi
fi

# If existing clr.json file is older than 48h, let's download it.
if find ${clrfile} -mmin +$((48*60)) -print | grep -q clr.json; then
    echo "Updating the CLR metadadata information."
    if curl -sL -o ${clrfile}.tmp $jsonclrurl; then
        mv ${clrfile}.tmp ${clrfile}
    else
        echo "Problem updating CLR metadadata information."
        # Touch cached one, so next run will work.
        touch ${clrfile}
        echo "Using existing cached metadata file for next (48h) runs. You can now execute this again."
        echo "Please, verify the causes of the download problem."
        exit 1
    fi
fi

# Verify that the CLR metadata is a correct JSON file.
if ! jq empty ${clrfile} 2>/dev/null; then
    echo "The CLR metadata information is not valid JSON."
    rm -f ${clrfile}
    exit 1
fi

# Metadata CLR file ok, let's print some details.
validuntil=$(date -d "$(date -r "${clrfile}")+48 hours" -u)
echo "Using cached (until ${validuntil}) CLR metadata information."

source ${mydir}/lib.sh # Add all the functions.

# Search for all the issues awaiting for integration and not being decided between CLR/IR.
# Note: customfield_10118 is the peer reviewer custom field.
${basereq} --action getIssueList \
           --jql "filter = 23535" \
           --columns="Key,Assignee,Peer reviewer,Components,Security Level,Summary" \
           --outputFormat=4 \
           --outputType=json \
           --file "${resultfile}"

# If there aren't issues, we have finished.
if ! grep -q '"components":' "${resultfile}"; then
    echo "No issues to process."
    # Remove the resultfile. We don't want to disclose those details.
    rm -fr "${resultfile}"
    exit 0
fi

# Iterate over found issues and perform the actions with them.
jq -c '.[]' ${resultfile} | while read json; do
    # Get the issue
    issue=$(jq -r '.key' <<< $json)
    echo "Processing ${issue}"
    # Get assignee, peer reviewer and components.
    assignee=$(jq -r '.assignee' <<< $json)
    peerreviewer=$(jq -r '.peerReviewer' <<< $json)
    components=$(jq -r '.components' <<< $json)
    # Get summary and security level.
    summary=$(jq -r '.summary' <<< $json)
    securitylevel=$(jq -r '.securityLevel' <<< $json)

    # Reset the outcome (defaults to no action and no description).
    outcome=
    outcomedesc=

    # Let's calculate the CLR/IR outcome.
    triage_issue

    # Arrived here, if we have an outcome, we are going to set the "Component Lead Review" field, only if $quiet is false.
    if [[ ${quiet} == "false" ]] && [[ -n ${outcome} ]]; then
        # Let's see if there is any restriction to the comment in the Tracker
        restrictiontype=
        if [[ -n "${restrictedto}" ]]; then
            restrictiontype=--role
        fi
        echo "  - Sending results to the Tracker (${restrictiontype} ${restrictedto})"

        # For fields available in the default screen, it's ok to use updateIssue or SetField, but in this case
        # we are setting some custom fields not available (on purpose) on that screen. So we have created a
        # global transition, only available to the bots, not transitioning but bringing access to all the fields
        # via special screen. So we'll ne using that global transition via transitionIssue instead.
        # customfield_15810 is the "Component Lead Review" field (Yes => CLR, No => IR, empty => undecided).
        if [[ "${outcome}" == "IR" ]]; then
            # No CLR. Just update the field.
            ${basereq} --action transitionIssue \
                       --issue ${issue} \
                       --transition "CI Global Self-Transition" \
                       --field "customfield_15810=No"
        else
            # CLR. Real transition to Waiting for CLR.
            ${basereq} --action transitionIssue \
                       --issue ${issue} \
                       --transition "Send to Component Leads Review"
        fi

        # Now, if there is some outcome description, add it as a comment.
        if [[ -n ${outcomedesc} ]]; then
            if [[ -n "${restrictedto}" ]]; then
                # Comment restricted.
                ${basereq} --action addComment \
                           --issue ${issue} \
                           --comment "${outcomedesc}" \
                           ${restrictiontype} "${restrictedto}"
            else
                # Comment not restricted.
                ${basereq} --action addComment \
                           --issue ${issue} \
                           --comment "${outcomedesc}"
            fi
        fi

        # Finally, feed the log file with the processed outcomes.
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} ${outcome} ${outcomedesc}" >> "${logfile}"
    else
        # This is a quiet run, just output the outcome.
        echo "  - Outcome: $outcome"
        echo "  - Comment: $outcomedesc"
    fi
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

#!/usr/bin/env bash
# Look for issues known to need their integration priority lowered.
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user

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
resultfile=$WORKSPACE/set_integration_priority_to_zero.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/set_integration_priority_to_zero.log

# Calculate some variables
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# Note this could be done by one unique "runFromIssueList" action, but we are splitting
# the search and the update in order to log all the reopenend issues within jenkins ($logfile)

# Let's search all the issues in Moodle project:
#   - Under current integration having NULL integration priority
#   - Awaiting for integration having NULL integration priority
#   - Reopened having integration priority set
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND ( \
                     ('Currently in integration' = 'Yes' AND 'Integration priority' IS EMPTY) \
                     OR \
                     (status = 'Waiting for integration review' AND 'Integration priority' IS EMPTY) \
                     OR \
                     (status = 'Reopened' AND 'Integration priority' is NOT EMPTY AND 'Integration priority' > 0) \
                 )" \
           --file "${resultfile}"

# Iterate over found issues and set their integration priority to 0.
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action transitionIssue \
        --issue ${issue} \
        --transition "CI Global Self-Transition" \
        --field "${customfield_integrationPriority}"=0
    echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
done

# Now, let's look for all the issues, also having > 0 integration priority and
# being under current integration or awaiting integration. Lower the integration
# priority for those being blocked by unresolved issues.
#
# Note that this can be achieved using a simple query using features provided by the J-Tricks
# plugin (and others), but they won't be compatible with Jira Cloud instances, so we are doing
# it using exclusively JiraCLI and its facilities (requiring multiple actions to be executed).

# First, get all the issues that are blocked by others and are not CLR.
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND 'Integration priority' > 0 \
                 AND ( \
                       ('Currently in integration' = 'Yes' AND status != 'Reopened') \
                       OR status = 'Waiting for integration review' \
                     ) \
                 AND issueLinkType = 'is blocked by' \
                 AND 'Component Lead Review' != 'Yes'" \
           --file "${resultfile}"

# Iterate over found issues and get its list of links being "is blocked by"
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action getLinkList \
               --issue "${issue}" \
               --columns "To Issue" \
               --regex "(?i)is blocked by" \
               --file "${resultfile}"

    # Iterate over found "is blocked by" issues and concat them for the next query.
    blockedbyissues=
    for linkedissue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        blockedbyissues="${blockedbyissues} ${linkedissue},"
    done
    blockedbyissues=${blockedbyissues%?}

    # If there aren't unresolved blockers, skip this issue.
    if [[ -z ${blockedbyissues} ]]; then
        echo "  skipping this issue (unable to find MDL blockers)"
        echo
        continue
    fi

    # Now let's see if any of the blockedby issues is unresolved.
    # (note that, since JiraCLU 8.1, getIssueCount can be used instead, but we are using older)
    if [[ -n ${blockedbyissues} ]]; then
        ${basereq} --action getIssueList \
                   --jql "resolution = Unresolved AND issue IN (${blockedbyissues})" \
                   --file "${resultfile}"
        # If there are issues returned... then the issue still has unresolved blockers.
        unresolvedfound=
        for unresolvedissue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
            echo "  ${unresolvedissue} blocks it and it is unresolved."
            unresolvedfound=1
        done

        # If there aren't unresolved blockers, skip this issue.
        if [[ -z ${unresolvedfound} ]]; then
            echo "  skipping this issue (all blockers are resolved)"
            echo
            continue
        fi
    fi

    # Arrived here, this is an issue that is blocked by some unresolved issue.
    # So we lower  its priority here and now.
    echo "  lowering its integration priority to 0 (has unresolved blockers)"
    echo
    ${basereq} --action transitionIssue \
        --issue ${issue} \
        --transition "CI Global Self-Transition" \
        --field "${customfield_integrationPriority}"=0
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue}" >> "${logfile}"
    echo
done

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"

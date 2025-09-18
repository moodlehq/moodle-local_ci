#!/usr/bin/env bash
# Functions for normal_manage_queues.sh, look there
# for details and nomenclature used.

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

# A, move "important" issues from candidates to current
function run_A() {
    # Get the list of issues.
    ${basereq} --action getIssueList \
               --jql "filter='${filter_candidatesForIntegration}'
                     AND NOT filter = '${filter_issuesHeldUntilAfterRelease}'
                     AND (
                       filter = '${filter_mustFixIssues}' OR
                       labels IN (mdlqa) OR
                       priority IN (Critical, Blocker) OR
                       level IS NOT EMPTY OR
                       component IN ('Privacy', 'Automated functional tests (behat)', 'Unit tests')
                     )" \
               --file "${resultfile}"

    # Iterate over found issues and perform the actions with them.
    for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        echo "Processing ${issue}"
        # If it's blocked by unresolved, don't move it to current.
        if is_blocked_by_unresolved $issue; then
            if [ -n "${dryrun}" ]; then
                echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} not moved (blocked by unresolved): important"
                continue
            fi
            echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} not moved (blocked by unresolved): important" >> "${logfile}"
            continue
        fi

        # Arriving here, we assume we are going to proceed with the move.
        if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: important"
            continue
        fi
        # For fields available in the default screen, it's ok to use updateIssue or SetField, but in this case
        # we are setting some custom fields not available (on purpose) on that screen. So we have created a
        # global transition, only available to the bots, not transitioning but bringing access to all the fields
        # via special screen. So we'll ne using that global transition via transitionIssue instead.
        # Also, there is one bug in the 4.4.x series, setting the destination as 0, leading to error in the
        # execution, so the form was hacked in the browser to store correct -1: https://jira.atlassian.com/browse/JRA-25002
        # Commented below, it's the "ideal" code. If some day JIRA changes that restriction we could stop using
        # that non-transitional transition and use normal update.
        #${basereq} --action updateIssue \
        #    --issue ${issue} \
        #    --field="${customfield_integrator}"= --field="${customfield_integrationDate}"= --field="${customfield_currentlyInIntegration}"=Yes
        ${basereq} --action transitionIssue \
                   --issue ${issue} \
                   --transition "CI Global Self-Transition" \
                   --field "${customfield_currentlyInIntegration}"=Yes \
                   --field "${customfield_componentLeadReview}"=No \
                   --field "${customfield_integrator}"= \
                   --field "${customfield_tester}"=

        ${basereq} --action addComment \
                   --issue ${issue} \
                   --comment "Normal queues manage: Moving to current because it's important" \
                   --role "Integrators"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: important" >> "${logfile}"
    done
}

# B, keep the current queue fed with bug issues when it's under a threshold.
function run_B() {
    # Count the list of issues in the current queue. (We cannot use getIssueCount till bumping to Jira CLI 8.1, hence, old way)
    ${basereq} --action getIssueList \
               --jql "project = MDL \
                     AND 'Currently in integration' IS NOT EMPTY \
                     AND status IN ('Waiting for integration review')" \
               --file "${resultfile}"

    # Iterate over found issues just to count them.
    counter=0
    for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        counter=$((counter+1))
    done
    echo "$counter issues awaiting integration in current queue"

    # If there are < $currentmin issues, let's add up to $movemax issues from the candidates queue.
    if [[ "$counter" -lt "$currentmin" ]]; then
        # Get an ordered list of up to issues in the candidate queue.
        ${basereq} --action getIssueList \
                   --jql "filter='${filter_candidatesForIntegration}' \
                       ORDER BY Rank ASC" \
                   --file "${resultfile}"

        # Iterate over found issues, moving up to $movemax of them to the current queue (cleaning integrator and tester).
        moved=0
        for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
            # Already have moved $movemax issues, stop processing more issues.
            if [[ $moved -eq $movemax ]]; then
                break
            fi
            echo "Processing ${issue}"
            # If it's blocked by unresolved, don't move it to current.
            if is_blocked_by_unresolved $issue; then
                if [ -n "${dryrun}" ]; then
                    echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} not moved (blocked by unresolved): threshold"
                    continue
                fi
                echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} not moved (blocked by unresolved): threshold" >> "${logfile}"
                continue
            fi

            # Arriving here, we assume we are going to proceed with the move.
            moved=$((moved+1))
            if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: threshold"
                continue
            fi
            # For fields available in the default screen, it's ok to use updateIssue or SetField, but in this case
            # we are setting some custom fields not available (on purpose) on that screen. So we have created a
            # global transition, only available to the bots, not transitioning but bringing access to all the fields
            # via special screen. So we'll ne using that global transition via transitionIssue instead.
            # Also, there is one bug in the 4.4.x series, setting the destination as 0, leading to error in the
            # execution, so the form was hacked in the browser to store correct -1: https://jira.atlassian.com/browse/JRA-25002
            # Commented below, it's the "ideal" code. If some day JIRA changes that restriction we could stop using
            # that non-transitional transition and use normal update.
            #${basereq} --action updateIssue \
            #    --issue ${issue} \
            #    --field="${customfield_integrator}"= --field="${customfield_integrationDate}"= --field="${customfield_currentlyInIntegration}"=Yes
            ${basereq} --action transitionIssue \
                    --issue ${issue} \
                    --transition "CI Global Self-Transition" \
                    --field "${customfield_currentlyInIntegration}"=Yes \
                    --field "${customfield_componentLeadReview}"=No \
                    --field "${customfield_integrator}"= \
                    --field "${customfield_tester}"=

            ${basereq} --action addComment \
                       --issue ${issue} \
                       --comment "Normal queues manage: Moving to current given we are below the threshold ($currentmin)" \
                       --role "Integrators"
            echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: threshold" >> "${logfile}"
        done
    fi
}
# C, raise the integration priority of issues awaiting too long in the candidates queue.
function run_C() {
    # Get the list of issues.
    ${basereq} --action getIssueList \
               --jql "filter='${filter_candidatesForIntegration}'
                     AND 'Integration priority' = 0
                     AND NOT (issueLinkType = 'blocks' OR issueLinkType = 'is blocked by')
                     AND NOT status CHANGED AFTER -${waitingdays}d" \
               --file "${resultfile}"

    # Iterate over found issues and perform the actions with them.
    for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        echo "Processing ${issue}"
        if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} raised integration priority"
            continue
        fi
        # For fields available in the default screen, it's ok to use updateIssue or SetField, but in this case
        # we are setting some custom fields not available (on purpose) on that screen. So we have created a
        # global transition, only available to the bots, not transitioning but bringing access to all the fields
        # via special screen. So we'll ne using that global transition via transitionIssue instead.
        # Also, there is one bug in the 4.4.x series, setting the destination as 0, leading to error in the
        # execution, so the form was hacked in the browser to store correct -1: https://jira.atlassian.com/browse/JRA-25002
        # Commented below, it's the "ideal" code. If some day JIRA changes that restriction we could stop using
        # that non-transitional transition and use normal update.
        #${basereq} --action updateIssue \
        #    --issue ${issue} \
        #    --field="${customfield_integrator}"= --field="${customfield_integrationDate}"= --field="${customfield_currentlyInIntegration}"=Yes
        ${basereq} --action transitionIssue \
                   --issue ${issue} \
                   --transition "CI Global Self-Transition" \
                   --field "${customfield_integrationPriority}"=1

        ${basereq} --action addComment \
                   --issue ${issue} \
                   --comment "Normal queues manage: Raising integration priority after ${waitingdays} days awaiting" \
                   --role "Integrators"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} raised integration priority" >> "${logfile}"
    done
}

# Given an issue (1st param), detect if it is blocked by some, still unresolved, issue.
function is_blocked_by_unresolved() {
    unresolvedfound=0

    ${basereq} --action getLinkList \
               --issue "$1" \
               --columns "To Issue" \
               --regex "(?i)is blocked by" \
               --file "${resultfile}.2"

    # Iterate over found "is blocked by" issues and concat them for the next query.
    blockedbyissues=
    for linkedissue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}.2" ); do
        blockedbyissues="${blockedbyissues} ${linkedissue},"
    done
    blockedbyissues=${blockedbyissues%?}

    # Now let's see if any of the blockedby issues is unresolved.
    # (note that, since JiraCLI 8.1, getIssueCount can be used instead, but we are using older)
    if [[ -n ${blockedbyissues} ]]; then
        ${basereq} --action getIssueList \
                   --jql "resolution = Unresolved AND issue IN (${blockedbyissues})" \
                   --file "${resultfile}.2"
        # If there are issues returned... then the issue still has unresolved blockers.
        for unresolvedissue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}.2" ); do
            unresolvedfound=$((unresolvedfound+1))
        done
    fi
    rm -fr "${resultfile}.2"
    if [[ $unresolvedfound -gt 0 ]]; then
        echo "    is blocked by $unresolvedfound unresolved issues"
        return 0 # Exit code, meaning true, blocked.
    fi
    return 1 # Exit code, meaning false, not blocked.
}

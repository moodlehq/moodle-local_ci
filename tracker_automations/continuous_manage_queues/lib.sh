#!/usr/bin/env bash
# Functions for continuous_manage_queues.sh, look there
# for details and nomenclature used.

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass releasedate"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# A1, add the "integration_held" + standard comment to any new feature or improvement arriving to candidates (IR & CLR)
function run_A1() {
    # Note this could be done by one unique "runFromIssueList" action, but we are splitting
    # the search and the update in order to log all the closed issues within jenkins ($logfile)

    # Basically get all the issues in the candidates queues (filter=14000 OR filter=23329), that are not bug
    # and that haven't received any comment with the standard unholding text (NOT filter = 22054)

    # Get the list of issues.
    ${basereq} --action getIssueList \
               --jql "(filter=14000 OR filter=23329) \
                     AND type IN ('New Feature', Improvement) \
                     AND NOT filter = 22054" \
               --file "${resultfile}"

    # Iterate over found issues and perform the actions with them.
    for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        echo "Processing ${issue}"
        if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} integration_held added"
            continue
        fi
        # Add the integration_held label.
        ${basereq} --action addLabels \
                   --issue ${issue} \
                   --labels "integration_held"
        # Add the standard comment for held issues.
        comment='This issue has been sent to integration after the freeze.

If you want Moodle HQ to consider including it into the incoming major release please add the "{{unhold_requested}}" label, and post a comment here outlining good reasons why you think it should be considered for late integration into the next major release.'

        ${basereq} --action addComment \
                   --issue ${issue} \
                   --comment "${comment}"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} integration_held added" >> "${logfile}"
    done
}

# A2, move "important" issues from candidates to current
function run_A2() {
    # Get the list of issues.
    ${basereq} --action getIssueList \
               --jql "filter=14000
                     AND NOT filter = 21366
                     AND (
                       filter = 21363 OR
                       labels IN (mdlqa)
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
        #    --field="customfield_10110=" --field="customfield_10210=" --field="customfield_10211=Yes"
        ${basereq} --action transitionIssue \
                   --issue ${issue} \
                   --transition "CI Global Self-Transition" \
                   --field "customfield_10211=Yes" \
                   --field "customfield_15810=No" \
                   --field "customfield_10110=" \
                   --field "customfield_10011=" \
                   --comment "Continuous queues manage: Moving to current because it's important" \
                   --role "Integrators"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: important" >> "${logfile}"
    done
}

# A3a, keep the current queue fed with bug issues when it's under a threshold.
function run_A3a() {
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
        # Get an ordered list of issues in the candidate queue.
        ${basereq} --action getIssueList \
                   --jql "filter=14000 \
                       ORDER BY Rank ASC" \
                   --file "${resultfile}"

        # Iterate over found issues, moving up to $movemax of them to the current queue (cleaning integrator and tester).
        moved=0
        for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
            # Already have moved $movemax issues, stop processing more issues.
            if [[ "$moved" -eq "$movemax" ]]; then
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
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: threshold (before ${lastweekdate})"
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
            #    --field="customfield_10110=" --field="customfield_10210=" --field="customfield_10211=Yes"
            ${basereq} --action transitionIssue \
                       --issue ${issue} \
                       --transition "CI Global Self-Transition" \
                       --field "customfield_10211=Yes" \
                       --field "customfield_15810=No" \
                       --field "customfield_10110=" \
                       --field "customfield_10011=" \
                       --comment "Continuous queues manage: Moving to current given we are below the threshold ($currentmin)" \
                       --role "Integrators"
            echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: threshold (before ${lastweekdate})" >> "${logfile}"
        done
    fi
}

# A3b, add the "integration_held" + standard comment to any issue arriving to candidates (IR & CLR).
function run_A3b() {
    # Get the list of issues in the candidates queues (IR & CLR). All them will be held with last week comment.
    ${basereq} --action getIssueList \
               --jql "filter=14000 OR filter=23329" \
               --file "${resultfile}"

    # Iterate over found issues, moving them to the current queue.
    for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        echo "Processing ${issue}"
        if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} integration_held last-week added (after ${lastweekdate})"
            continue
        fi
        # Add the integration_held label.
        ${basereq} --action addLabels \
                   --issue ${issue} \
                   --labels "integration_held"
        # Add the standard comment for held issues the last week.
        comment='We are currently in the [final week before release|https://moodledev.io/general/development/process/integration#during-continuous-integrationfreezeqa-period] so this issue is being held until after release. Thanks for your patience!'
        ${basereq} --action addComment \
                   --issue ${issue} \
                   --comment "${comment}"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} integration_held last-week added (after ${lastweekdate})" >> "${logfile}"
    done
}

# B1b, keep the current queue fed with bug issues when it's under a threshold.
function run_B1b() {
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
        # Get an ordered list of issues in the candidate queue.
        ${basereq} --action getIssueList \
                   --jql "filter=14000 \
                       ORDER BY Rank ASC" \
                   --file "${resultfile}"

        # Iterate over found issues, moving up to $movemax of them to the current queue (cleaning integrator and tester).
        moved=0
        for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
            # Already have moved $movemax issues, stop processing more issues.
            if [[ "$moved" -eq "$movemax" ]]; then
                break
            fi
            echo "Processing ${issue}"
            # If it's blocked by unresolved, don't move it to current.
            if is_blocked_by_unresolved $issue; then
                if [ -n "${dryrun}" ]; then
                    echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} not moved on-sync (blocked by unresolved): threshold"
                    continue
                fi
                echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} not moved on-sync (blocked by unresolved): threshold" >> "${logfile}"
                continue
            fi

            # Arriving here, we assume we are going to proceed with the move.
            moved=$((moved+1))
            if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current on-sync: threshold"
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
            #    --field="customfield_10110=" --field="customfield_10210=" --field="customfield_10211=Yes"
            ${basereq} --action transitionIssue \
                       --issue ${issue} \
                       --transition "CI Global Self-Transition" \
                       --field "customfield_10211=Yes" \
                       --field "customfield_15810=No" \
                       --field "customfield_10110=" \
                       --field "customfield_10011=" \
                       --comment "Continuous queues manage: Moving to current given we are below the threshold ($currentmin)" \
                       --role "Integrators"
            echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current on-sync: threshold" >> "${logfile}"
        done
    fi
}

# B1a, add the "integration_held" + standard on-sync comment to any new feature or improvement arriving to candidates (IR & CLR).
function run_B1a() {
    # Note this could be done by one unique "runFromIssueList" action, but we are splitting
    # the search and the update in order to log all the closed issues within jenkins ($logfile)

    # Basically get all the issues in the candidates queues (filter=14000 OR filter=23329), that are not bug
    # and that haven't received any comment with the standard unholding text (NOT filter = 22054)

    # Get the list of issues.
    ${basereq} --action getIssueList \
               --jql "(filter=14000 OR filter=23329) \
                     AND type IN ('New Feature', Improvement) \
                     AND NOT filter = 22054" \
               --file "${resultfile}"

    # Iterate over found issues and perform the actions with them.
    for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        echo "Processing ${issue}"
        if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} integration_held on-sync added"
            continue
        fi
        # Add the integration_held label.
        ${basereq} --action addLabels \
                   --issue ${issue} \
                   --labels "integration_held"
        # Add the standard comment for held issues.
        comment='We are currently in the [On-sync period|https://moodledev.io/general/development/process/integration#on-sync-period] so this issue is being held until we leave that period in a few weeks time. Thanks for your patience!'.

        ${basereq} --action addComment \
                   --issue ${issue} \
                   --comment "${comment}"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} integration_held on-sync added" >> "${logfile}"
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

# Move, always, all held issues awaiting for integration away from current integration.
function run_C() {
    # Count the list of issues in the current queue. (We cannot use getIssueCount till bumping to Jira CLI 8.1, hence, old way)
    ${basereq} --action getIssueList \
               --jql "project = MDL \
                     AND 'Currently in integration' IS NOT EMPTY \
                     AND status IN ('Waiting for integration review') \
                     AND labels in (security_held, integration_held)" \
               --file "${resultfile}"
    # Let's iterate over found issues.
    for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        echo "Processing ${issue}"
        if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved out from current because it's held"
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
        #    --field="customfield_10110=" --field="customfield_10210=" --field="customfield_10211=Yes"
        ${basereq} --action transitionIssue \
                   --issue ${issue} \
                   --transition "CI Global Self-Transition" \
                   --field "customfield_10211=" \
                   --field "customfield_10110=" \
                   --field "customfield_10011=" \
                   --comment "Continuous queues manage: Moving out from current because it's held" \
                   --role "Integrators"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved out from current: held" >> "${logfile}"
    done
}

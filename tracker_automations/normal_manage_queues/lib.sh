#!/usr/bin/env bash
# Functions for normal_manage_queues.sh, look there
# for details and nomenclature used.

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

# A, move "important" issues from candidates to current
function run_A() {
    # Get the list of issues.
    ${basereq} --action getIssueList \
               --search "filter=14000
                     AND NOT filter = 21366
                     AND (
                       filter = 21363 OR
                       labels IN (mdlqa) OR
                       priority IN (Critical, Blocker) OR
                       level IS NOT EMPTY OR
                       component IN ('Privacy', 'Automated functional tests (behat)', 'Unit tests')
                     )" \
               --file "${resultfile}"

    # Iterate over found issues and perform the actions with them.
    for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
        echo "Processing ${issue}"
        if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: important"
            continue
        fi
        # For fields available in the default screen, it's ok to use updateIssue or SetField, but in this case
        # we are setting some custom fields not available (on purpose) on that screen. So we have created a
        # global transition, only available to the bots, not transitioning but bringing access to all the fields
        # via special screen. So we'll ne using that global transition via progressIssue instead.
        # Also, there is one bug in the 4.4.x series, setting the destination as 0, leading to error in the
        # execution, so the form was hacked in the browser to store correct -1: https://jira.atlassian.com/browse/JRA-25002
        # Commented below, it's the "ideal" code. If some day JIRA changes that restriction we could stop using
        # that non-transitional transition and use normal update.
        #${basereq} --action updateIssue \
        #    --issue ${issue} \
        #    --custom "customfield_10110:,customfield_10210:,customfield_10211:Yes"
        ${basereq} --action progressIssue \
                   --issue ${issue} \
                   --step "CI Global Self-Transition" \
                   --custom "customfield_10211:Yes,customfield_10110:,customfield_10011:" \
                   --comment "Normal queues manage: Moving to current because it's important" \
                   --role "Integrators"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: important" >> "${logfile}"
    done
}

# B, keep the current queue fed with bug issues when it's under a threshold.
function run_B() {
    # Count the list of issues in the current queue. (We cannot use getIssueCount till bumping to Jira CLI 8.1, hence, old way)
    ${basereq} --action getIssueList \
               --search "project = MDL \
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
        # Get an ordered list of up to $movemax issues in the candidate queue.
        ${basereq} --action getIssueList \
                   --limit $movemax \
                   --search "filter=14000 \
                       ORDER BY 'Integration priority' DESC, \
                                priority DESC, \
                                votes DESC, \
                                'Last comment date' ASC" \
                   --file "${resultfile}"

        # Iterate over found issues, moving them to the current queue (cleaning integrator and tester).
        for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${resultfile}" ); do
            echo "Processing ${issue}"
            if [ -n "${dryrun}" ]; then
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: threshold"
                continue
            fi
            # For fields available in the default screen, it's ok to use updateIssue or SetField, but in this case
            # we are setting some custom fields not available (on purpose) on that screen. So we have created a
            # global transition, only available to the bots, not transitioning but bringing access to all the fields
            # via special screen. So we'll ne using that global transition via progressIssue instead.
            # Also, there is one bug in the 4.4.x series, setting the destination as 0, leading to error in the
            # execution, so the form was hacked in the browser to store correct -1: https://jira.atlassian.com/browse/JRA-25002
            # Commented below, it's the "ideal" code. If some day JIRA changes that restriction we could stop using
            # that non-transitional transition and use normal update.
            #${basereq} --action updateIssue \
            #    --issue ${issue} \
            #    --custom "customfield_10110:,customfield_10210:,customfield_10211:Yes"
            ${basereq} --action progressIssue \
                       --issue ${issue} \
                       --step "CI Global Self-Transition" \
                       --custom "customfield_10211:Yes,customfield_10110:,customfield_10011:" \
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
               --search "filter=14000
                     AND 'Integration priority' = 0
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
        # via special screen. So we'll ne using that global transition via progressIssue instead.
        # Also, there is one bug in the 4.4.x series, setting the destination as 0, leading to error in the
        # execution, so the form was hacked in the browser to store correct -1: https://jira.atlassian.com/browse/JRA-25002
        # Commented below, it's the "ideal" code. If some day JIRA changes that restriction we could stop using
        # that non-transitional transition and use normal update.
        #${basereq} --action updateIssue \
        #    --issue ${issue} \
        #    --custom "customfield_10110:,customfield_10210:,customfield_10211:Yes"
        ${basereq} --action progressIssue \
                   --issue ${issue} \
                   --step "CI Global Self-Transition" \
                   --custom "customfield_12210:1" \
                   --comment "Normal queues manage: Raising integration priority after ${waitingdays} days awaiting" \
                   --role "Integrators"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} raised integration priority" >> "${logfile}"
    done
}

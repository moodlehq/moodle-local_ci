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

# A1, add the "integration_held" + standard comment to any new feature or improvement arriving to candidates.
function run_A1() {
    # Note this could be done by one unique "runFromIssueList" action, but we are splitting
    # the search and the update in order to log all the closed issues within jenkins ($logfile)

    # Basically get all the issues in the candidates queue (filter=14000), that are not bug
    # and that haven't received any comment with the standard unholding text (NOT filter = 22054)

    # Get the list of issues.
    ${basereq} --action getIssueList \
               --search "filter=14000 \
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
                   --comment "Continuous queues manage: Moving to current because it's important" \
                   --role "Integrators"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: important" >> "${logfile}"
    done
}

# A3a, keep the current queue fed with bug issues when it's under a threshold.
function run_A3a() {
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
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: threshold (before ${lastweekdate})"
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
                       --comment "Continuous queues manage: Moving to current given we are below the threshold ($currentmin)" \
                       --role "Integrators"
            echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current: threshold (before ${lastweekdate})" >> "${logfile}"
        done
    fi
}

# A3b, add the "integration_held" + standard comment to any issue arriving to candidates.
function run_A3b() {
    # Get the list of issues in the candidates queue. All them will be held with last week comment.
    ${basereq} --action getIssueList \
               --search "filter=14000" \
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
        comment='We are currently in the final week before release ( https://docs.moodle.org/dev/Integration_Review#During_continuous_integration.2FFreeze.2FQA_period ) so this issue is being held until after release. Thanks for your patience!'
        ${basereq} --action addComment \
                   --issue ${issue} \
                   --comment "${comment}"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} integration_held last-week added (after ${lastweekdate})" >> "${logfile}"
    done
}

# B1a, keep the current queue fed with bug issues when it's under a threshold.
function run_B1a() {
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
            echo "Dry-run: $BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current on-sync: threshold"
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
                       --comment "Continuous queues manage: Moving to current given we are below the threshold ($currentmin)" \
                       --role "Integrators"
            echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} moved to current on-sync: threshold" >> "${logfile}"
        done
    fi
}

# B1b, add the "integration_held" + standard on-sync comment to any new feature or improvement arriving to candidates.
function run_B1b() {
    # Note this could be done by one unique "runFromIssueList" action, but we are splitting
    # the search and the update in order to log all the closed issues within jenkins ($logfile)

    # Basically get all the issues in the candidates queue (filter=14000), that are not bug
    # and that haven't received any comment with the standard unholding text (NOT filter = 22054)

    # Get the list of issues.
    ${basereq} --action getIssueList \
               --search "filter=14000 \
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
        comment='We are currently in the on-sync period ( https://docs.moodle.org/dev/Integration_Review#On-sync_period ) so this issue is being held until we leave that period in a few weeks time. Thanks for your patience!'.

        ${basereq} --action addComment \
                   --issue ${issue} \
                   --comment "${comment}"
        echo "$BUILD_NUMBER $BUILD_TIMESTAMP ${issue} integration_held on-sync added" >> "${logfile}"
    done

}

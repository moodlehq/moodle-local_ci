#!/usr/bin/env bash
#
# This file contains the standard configuration relating to all queries used for tracker automations.
# Any use of numeric custom fields or filters should be defined here.
# This file should be sourced by any script that needs to use the tracker.

set -e

customfield_automatedTestResults="Automated test results"
customfield_componentLeadReview="Component Lead Review"
customfield_currentlyInIntegration="Currently in integration"
customfield_integrationDate="Integration date"
customfield_integrationPriority="Integration priority"
customfield_integrator="Integrator"
customfield_pullFromRepository="Pull  from Repository"
customfield_tester="Tester"


filter_candidatesForCLR="Weekly: Candidates for CLR (not held)"
filter_candidatesForIntegration="Weekly: Candidates for Integration (not held)"
filter_integrationCLRDecision="Weekly: Issues to decide between IR/CLR"
filter_issuesHeldUntilAfterRelease="Issues agreed to be after release"
filter_issuesVotedToUnhold="Issues that have been voted for unhold"
filter_issuesWaitingForReviewOrInProgress="Integration: Current queue for issues waiting for review or review in progress"
filter_mustFixIssues="All \"must-fix\" issues"

# Verify everything is set
required="jiraclicmd jiraserver jirauser jirapass"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Set the base request command.
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"

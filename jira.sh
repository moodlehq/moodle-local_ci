#!/usr/bin/env bash
#
# This file contains the standard configuration relating to all queries used for tracker automations.
# Any use of numeric custom fields or filters should be defined here.
# This file should be sourced by any script that needs to use the tracker.

set -e

customfield_automatedTestResults=17112
customfield_componentLeadReview=15810
customfield_currentlyInIntegration=10211
customfield_integrationDate=10210
customfield_integrationPriority=12210
customfield_integrator=10110
customfield_pullFromRepository=10100
customfield_tester=10011

filter_candidatesForCLR="Weekly: Candidates for CLR (not held)"
filter_candidatesForIntegration="Weekly: Candidates for Integration (not held)"
filter_integrationCLRDecision="Weekly: Issues to decide between IR/CLR"
filter_issuesHeldUntilAfterRelease="Issues agreed to be after release"
filter_issuesVotedToUnhold="Issues that have been voted for unhold"
filter_issuesWaitingForReviewOrInProgress="Integration: Current queue for issues waiting for peer review or review in progress"
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

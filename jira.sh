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

filter_candidatesForCLR=23329
filter_candidatesForIntegration=14000
filter_integrationCLRDecision=23535
filter_issuesHeldUntilAfterRelease=21366
filter_issuesVotedToUnhold=22054
filter_issuesWaitingForReviewOrInProgress=22610
filter_mustFixIssues=21363

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

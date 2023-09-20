#!/usr/bin/env bash
# Functions to triage issues between CLR/IR (used by component_leads_integration_mover.sh)

# Let's go strict (exit on error)
set -e

# Main function to apply for all the rules agreed and decide between CLR/IR.
# Note that, for now, none of the criteria include looking to code, but
# just makes a decision based on tracker information 100%. No matter of that,
# it's possible to create new criteria performing code verifications or
# anything else.
function triage_issue() {
    echo "  Issue: $issue, Assignee: $assignee, Peer reviewer: $peerreviewer, Components: $components"

    # Verify that all the components are valid. Send to integration if not.
    verify_components_are_valid && [[ -n $outcome ]] && return

    # Verify that all the components belong to the same group. Send to integration if not.
    verify_components_same_group && [[ -n $outcome ]] && return

    # Verify reviewers availability, checking the assignee and peer reviewers against the list of component reviewers.
    verify_revievers_availability && [[ -n $outcome ]] && return

    # To continue... adding more rules until we have all the devpad annotated ones covered.
}

function verify_components_are_valid {
    echo "  - verify_components_are_valid"

    # Trim it, just in case.
    components=$(trimstring "$components")
    # Verify that we have components
    if [[ ${#components} -eq 0 ]]; then
        echo "    - Problem: No components"
        outcome=IR
        outcomedesc="Sending to IR, the issue is missing components so it cannot be decided."
        return # Outcome set, we are done.
    fi

    # Verify that all the components are in the sheet
    IFS=, read -r -a componentsArr <<<"$components"
    for component in "${componentsArr[@]}"; do
        component=$(trimstring "$component")
        echo "    - component: $component"
        if [[ ! $(jq -e ".trackerComponents[] | select(.component == \"${component}\")" ${clrfile}) ]]; then
            echo "      - Problem: Component is not in the sheet."
            outcome=IR
            outcomedesc="Sending to IR, the \"${component}\" component is not in the sheet."
            return # Outcome set, we are done.
        fi
    done
}

function verify_components_same_group {
    echo "  - verify_components_same_group"

    # Trim it, just in case.
    components=$(trimstring "$components")

    # Verify that all the components belong to the same group
    leadgroup=
    IFS=, read -r -a componentsArr <<<"$components"
    for component in "${componentsArr[@]}"; do
        component=$(trimstring "$component")
        echo "    - component: $component"
        group=$(get_lead_component_group "${component}")
        if [[ -z ${group} ]]; then
            echo "      - Problem: Component \"${component}\" does not have a lead team assigned."
            outcome=IR
            outcomedesc="Sending to IR, the \"${component}\" component does not have a lead team assigned."
            return # Outcome set, we are done.
        fi
        if [[ -n ${leadgroup} ]] && [[ ${leadgroup} != ${group} ]]; then
            echo "      - Problem: Multiple lead groups detected: \"${leadgroup}\" and  \"${group}\"."
            outcome=IR
            outcomedesc="Sending to IR, multiple lead groups detected: \"${leadgroup}\" and \"${group}\"."
            return # Outcome set, we are done.
        fi
        leadgroup=${group}
    done
}

function verify_revievers_availability() {
    echo "  - verify_revievers_availability"

    # Trim it, just in case.
    components=$(trimstring "$components")

    # First, look if the components have some, specific or group, reviewers.
    leadreviewers=
    IFS=, read -r -a componentsArr <<<"$components"
    for component in "${componentsArr[@]}"; do
        reviewers=
        component=$(trimstring "$component")
        echo "    - component: $component"
        reviewers=$(get_lead_component_reviewers "${component}")
        reviewers=$(trimstring "$reviewers")
        reviewers=$(echo -n "${reviewers}" | tr -s '[:space:]' ',') # Cannot use <<<, it adds a \n.
        if [[ -z ${reviewers} ]]; then
            echo "      - Problem: Component \"${component}\" does not have any, specific or group, reviewer available."
            outcome=IR
            outcomedesc="Sending to IR, component \"${component}\" does not have any, specific or group, reviewer available."
            return # Outcome set, we are done.
        elif [[ -n ${leadreviewers} ]] && [[ ${leadreviewers} != ${reviewers} ]]; then
            echo "      - Problem: Conflicting component reviewers detected: \"${leadreviewers}\" and \"${reviewers}\"."
            outcome=IR
            outcomedesc="Sending to IR, conflicting component reviewers detected: \"${leadreviewers}\" and \"${reviewers}\"."
            return # Outcome set, we are done.
        fi
        leadreviewers=${reviewers}
    done
    echo "      - Reviewers: ${leadreviewers}"

    # We have some reviewers, verify that they are available and haven't played
    # any role in the issue (assignee or peer-reviewer)

}

function another {
    echo "  - another"
}

function trimstring() {
    if [ $# -ne 1 ]
    then
        echo "USAGE: trimstring [STRING]"
        return 1
    fi
    s="${1}"
    size_before=${#s}
    size_after=0
    while [ ${size_before} -ne ${size_after} ]
    do
        size_before=${#s}
        s="${s#[[:space:]]}"
        s="${s%[[:space:]]}"
        size_after=${#s}
    done
    echo "${s}"
    return 0
}

# Given a component, return the group that leads it
function get_lead_component_group() {
    if [ $# -ne 1 ]
    then
        echo "USAGE: get_lead_component_group [COMPONENT]"
        return 1
    fi
    local component="${1}"
    local group=

    group=$(jq -r ".trackerComponents[] | select(.component == \"${component}\") | .group" ${clrfile})
    group=$(trimstring "$group")
    echo "${group}"
    return
}

# Given a component, return the list of reviewers available for it.
# First look for component specific reviewer, then for group reviewers.
function get_lead_component_reviewers() {
    if [ $# -ne 1 ]
    then
        echo "USAGE: get_lead_component_reviewers [COMPONENT]"
        return 1
    fi
    local component="${1}"
    local reviewers=

    # First, look for component specific reviewers.
    reviewers=$(jq -r ".reviewersAvailability[] | select (.component == \"${component}\") .reviewers[]" ${clrfile})
    reviewers=$(trimstring "$reviewers")
    if [[ -n ${reviewers} ]]; then
        echo "${reviewers}"
        return
    fi

    # No specific reviewers found, let's look for group ones.
    # Let's find the leading group of the component.
    local group=$(get_lead_component_group "${component}")
    if [[ -n ${group} ]]; then
        reviewers=$(jq -r ".reviewersAvailability[] | select (.group == \"${group}\") .reviewers[]" ${clrfile})
        reviewers=$(trimstring "$reviewers")
        echo "${reviewers}"
        return
    fi
}

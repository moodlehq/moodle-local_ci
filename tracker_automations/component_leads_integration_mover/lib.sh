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

    # Verify if the issue is a backport request. Send to integration if so.
    verify_backport_request && [[ -n $outcome ]] && return

    # Verify if the issue is a security one. Send to integration if so.
    verify_security && [[ -n $outcome ]] && return

    # Verify that all the components are valid. Send to integration if not.
    verify_components_are_valid && [[ -n $outcome ]] && return

    # Verify that all the components belong to the same group. Send to integration if not.
    verify_components_same_group && [[ -n $outcome ]] && return

    # Verify reviewers availability, checking the assignee and peer reviewers
    # against the list of component reviewers.
    # Note that this verification always end with an outcome (IR or CLR).
    verify_revievers_availability && [[ -n $outcome ]] && return

    # Finished, just return.
    return 0
}

function verify_backport_request {
    echo "  - verify_backport_request"
    shopt -s nocasematch # case insensitive.
    if [[ "${summary}" =~ backport.*mdl-[0-9]+ ]]; then
        echo "    - Issue is a backport request."
        outcome=IR
        outcomedesc="Sending to IR, the issue is a backport request."
    else
        echo "    - Issue is not a backport request."
    fi
    shopt -u nocasematch # case sensitive.
}

function verify_security {
    echo "  - verify_security"
    if [[ -n ${securitylevel} ]]; then
        echo "    - Issue is a security one."
        outcome=IR
        outcomedesc="Sending to IR, the issue is a security one."
    else
        echo "    - Issue is not a security one."
    fi
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
        if ! jq -e ".trackerComponents[] | select(.component == \"${component}\") | .group" ${clrfile} >/dev/null; then
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
        elif [[ -n ${reviewers} ]] && [[ ${reviewers} == "EMPTY_SPECIFIC" ]]; then
            echo "      - Note: Component \"${component}\" is configured to go straight to integration"
            outcome=IR
            outcomedesc="Sending to IR, component \"${component}\" is configured to go straight to integration."
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
    available=$(tr ',' ' ' <<< "${leadreviewers}")
    # Check the assignee.
    if [[ ${available} =~ ${assignee} ]]; then
        echo "        - ${assignee} is not available because of being the assignee."
        available=${available//${assignee}/}
        available=$(trimstring "$available")
    fi
    # Check the peer-reviewer.
    if [[ ${available} =~ ${peerreviewer} ]]; then
        echo "        - ${peerreviewer} is not available because of being the peer reviewer."
        available=${available//${peerreviewer}/}
        available=$(trimstring "$available")
    fi
    # Arrived here, if we don't have any reviewer available, this goes to IR.
    if [[ -z ${available} ]]; then
        echo "      - Problem: None of the reviewers (${leadreviewers}) are available for the issue."
        outcome=IR
        outcomedesc="Sending to IR, none of the reviewers (${leadreviewers}) are available for the issue."
        return # Outcome set, we are done.
    fi

    # There is at least one component lead reviewer available, let's send the issue to CLR. This check is done.
    echo "      - There are available reviewers (${available}) for the issue."
    outcome=CLR
    availableProfiles=()
    IFS=' ' read -r -a availableCLRs <<<"$available"
    for availableCLR in "${availableCLRs[@]}"; do
        availableCLR=$(trimstring "$availableCLR")
        if [[ -z ${availableCLR} ]]; then
            continue
        fi
        # Due to GDPR, we cannot mention the email address of the reviewer, so we need to get the accountID.
        # File where accountID will be stored.
        accountfile=${WORKSPACE}/component_leads_integration_mover_accountid.txt
        echo -n > "${accountfile}"
        curl -u ${jirauser}:${jirapass} \
          -X GET "${baseapireq}user/search?query=${availableCLR}" > "${accountfile}"
        CLRAccountID=$(grep -o '"accountId":"[^"]*"' "${accountfile}" | head -n1 | sed 's/"accountId":"\([^"]*\)"/\1/')
        rm "${accountfile}"
        availableProfiles+=("[~accountId:${CLRAccountID}]")
    done
    outcomedesc=$(IFS=, ; echo "Sending to CLR, there are available reviewers for the issue: ${availableProfiles[*]}")
    return # Outcome set, and function finished we are done.
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
# First look for component specific reviewer, and, if there isn't any
# specific definition for the component, then look for for group reviewers.
# Note that it returns "EMPTY_SPECIFIC" when the component is configured
# without any reviewer (empty).
function get_lead_component_reviewers() {
    if [ $# -ne 1 ]
    then
        echo "USAGE: get_lead_component_reviewers [COMPONENT]"
        return 1
    fi
    local component="${1}"
    local reviewers=
    local specific=

    # Does the component have any specific configuration.
    if jq -e ".reviewersAvailability[] | select (.component == \"${component}\")" ${clrfile} >/dev/null; then
        specific=true
    fi

    # If there is a specific configuration, just use it, with or without reviewers.
    if [[ -n $specific ]]; then
        reviewers=$(jq -r ".reviewersAvailability[] | select (.component == \"${component}\") .reviewers[]" ${clrfile})
        reviewers=$(trimstring "$reviewers")
        if [[ -n ${reviewers} ]]; then
            echo "${reviewers}"
        else
            # Specific component is configured, but it doesn't have any reviewer.
            echo "EMPTY_SPECIFIC"
        fi
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

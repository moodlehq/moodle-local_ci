#!/usr/bin/env bash
# Look all reopened issues under current integration and move them out
#jiraclicmd: full execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#jenkinsserver: Full URL of the jenkins server where the jobs will be launched.
#jenkinsauth: String that defines the method to connect to the jenkins server, can be -ssh
#  (requiring keys to be in place and jenkins ssh enabled), or also -html (and then
#  use a combination of user and password or token). See Jenkins CLI docs for more info.
#cf_repository: id for "Pull from Repository" custom field (customfield_10100)
#cf_branches: comma separated trios of moodle branch, id for "Pull XXXX Branch" custom field and php version.
#             Trios are colon separated, example: main:customfield_10111:7.3,....). All them required.
#criteria: "awaiting integration"...
#schedulemins: Frecuency (in minutes) of the schedule (cron) of this job. IMPORTANT to ensure that they match or there will be issues processed more than once or skipped.
#jobtype: defaulting to "all", allows to just pick one of the available jobs: phpunit, behat-(firefox|chrome|nonjs|all).
#quiet: with any value different from "false", don't perform any action in the Tracker.

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass jenkinsserver jenkinsauth cf_repository cf_branches criteria schedulemins quiet"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# wipe the workspace
rm -fr "${WORKSPACE}"/*

# file where results will be sent
resultfile=${WORKSPACE}/bulk_prelaunch_jobs
echo -n > "${resultfile}"

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"

# Normalise criteria
criteria=${criteria// /_}

# Validate criteria
if [[ ! -f "${mydir}/criteria/${criteria}/query.sh" ]]; then
    echo "Error: Incorrect criteria '${criteria}'"
    exit 1
fi

echo "Using criteria: ${criteria}"

# Calculate jobtype (default to all).
jobtype=${jobtype:-all}

echo "Using jobtype: ${jobtype}"

# Execute the criteria query. It will save a list of issues (format 101) to $resultfile.
. "${mydir}/criteria/${criteria}/query.sh"

# Iterate over found issues and launch the prechecker for them
while read issue; do
    echo -n > "${resultfile}.${issue}.txt"
    echo "Results for ${issue} (${jiraserver}/browse/${issue})"
    # Fetch repository
    ${basereq} --action getFieldValue \
               --issue ${issue} \
               --field ${cf_repository} \
               --quiet \
               --file "${resultfile}.repository" > /dev/null
    repository=$(cat "${resultfile}.repository" | tr -d ' ')
    rm "${resultfile}.repository"
    if [[ -z "${repository}" ]]; then
        echo "(x) Error: the repository field is empty. Nothing was launched." | tee -a "${resultfile}.${issue}.txt"
    else
        echo "Issue ${issue} has git repository ${repository}"
    fi

    # Iterate over the candidate branches
    branchesfound=""
    for candidate in ${cf_branches//,/ }; do
        # Nothing to process with empty repository
        if [[ -z "${repository}" ]]; then
            break
        fi
        # Split into target branch, custom field and php version.
        arrcandidate=(${candidate//:/ })
        target=${arrcandidate[0]}
        cf_branch=${arrcandidate[1]}
        php_version=${arrcandidate[2]}
        # Verify we have all the information
        if [[ -z ${target} ]] || [[ -z ${cf_branch} ]] || [[ -z ${php_version} ]]; then
            echo "(x) Error: the branch definition ${candidate} is missing branch, custom field or php version. All them are required" | tee -a "${resultfile}.${issue}.txt"
            continue
        fi
        # Fetch branch information
        ${basereq} --action getFieldValue \
                   --issue ${issue} \
                   --field ${cf_branch} \
                   --quiet \
                   --file "${resultfile}.branch" > /dev/null
        branch=$(cat "${resultfile}.branch" | tr -d ' ')
        rm "${resultfile}.branch"

        # Branch found
        if [[ -n "${branch}" ]]; then
            branchesfound=1
            echo "Launching automatic jobs for branch ${branch}" | tee -a "${resultfile}.${issue}.txt"
            # Launch the jobs for current criteria (jobs.sh)
            jenkinsreq="java -jar ${mydir}/../../jenkins_cli/jenkins-cli.jar -s ${jenkinsserver} ${jenkinsauth} build"
            set +e
            . "${mydir}/criteria/${criteria}/jobs.sh"
            set -e
            # Only if we have got some new job registered in ${resultfile}.jenkinscli
            if [[ ! -f "${resultfile}.jenkinscli" ]]; then
                continue
            fi
            # Calculate the type, job names and build numbers
            regex="^([^:]+): Started ([^#]+) #([0-9]+)$"
            while read jobline; do
                [[ ${jobline} =~ ${regex} ]]
                if [[ -n ${BASH_REMATCH[0]} ]]; then
                    echo "  ${BASH_REMATCH[0]}"
                    type=${BASH_REMATCH[1]}
                    job=${BASH_REMATCH[2]}
                    build=${BASH_REMATCH[3]}
                    joburl="${jenkinsserver}/view/Testing/job/${job}/${build}/"
                    joburl=$(echo ${joburl} | sed 's/ /%20/g')
                    echo "    - Type: ${type}"
                    echo "    - Job: ${job}"
                    echo "    - Build: ${build}"
                    echo "    - URL: ${joburl}"
                    echo "    - Result: ${type}: ${joburl}"
                    echo "  - ${type}: ${joburl}" >> "${resultfile}.${issue}.txt"
                fi
            done < "${resultfile}.jenkinscli"
            echo "" >> "${resultfile}.${issue}.txt"
            rm "${resultfile}.jenkinscli"
        fi
    done
    echo "Built on: $(date -u)" >> "${resultfile}.${issue}.txt"

    echo ""
    # Verify we have processed some branch.
    if [[ ! -z  "${repository}" ]] && [[ -z "${branchesfound}" ]]; then
        echo "(x) Error: all the branch fields are incorrect. Nothing was checked." | tee -a "${resultfile}.${issue}.txt"
    fi

    # Execute the criteria postissue. It will perform the needed changes in the tracker for the current issue
    if [[ ${quiet} == "false" ]]; then
        echo "  - Sending results to the Tracker"
        . "${mydir}/criteria/${criteria}/postissue.sh"
    fi
done < "${resultfile}"

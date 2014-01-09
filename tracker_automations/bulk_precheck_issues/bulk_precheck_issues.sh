#!/bin/bash
# Look all reopened issues under current integration and move them out
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#cf_repository: id for "Pull from Repository" custom field (customfield_10100)
#cf_branches: pairs of moodle branch and id for "Pull XXXX Branch" custom field (master:customfield_10111,....)
#criteria: "awaiting peer review", "awaiting integration", "developer request"
#quiet: if enabled ("true"), don't perform any action in the Tracker.
#jenkinsjobname: job in the server that we are going to execute
#jenkinsserver: private jenkins server url (where the prechecker will be executed.
#               note this must be a direct url. no proxies/rewrites/redirects allowed. Usually http://localhost:8080.
#publishserver: public jenkins server url (where result will be available).
#               note this can be behind proxies, redirects... Public URL like http://integration.moodle.org.

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass cf_repository cf_branches criteria quiet jenkinsjobname jenkinsserver publishserver"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# wipe the workspace
rm -fr "${WORKSPACE}"/*

# file where results will be sent
resultfile=${WORKSPACE}/bulk_precheck_issues
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

# Execute the criteria query. It will save a list of issues (format 101) to $resultfile.
. "${mydir}/criteria/${criteria}/query.sh"

# Iterate over found issues and launch the prechecker for them
while read issue; do
    echo "Results for ${issue} (https://tracker.moodle.org/browse/${issue})"
    echo "Results for ${issue}" >> "${resultfile}.${issue}.txt"
    # Fetch repository
    ${basereq} --action getFieldValue \
               --issue ${issue} \
               --field ${cf_repository} \
               --file "${resultfile}.repository" > /dev/null
    repository=$(cat "${resultfile}.repository")
    rm "${resultfile}.repository"
    if [[ -z "${repository}" ]]; then
        echo "  - Error: the repository field is empty. Nothing was checked." | tee -a "${resultfile}.${issue}.txt"
    else
        echo "  - Remote repository: ${repository}" | tee -a "${resultfile}.${issue}.txt"
    fi

    # Iterate over the candidate branches
    branchesfound=""
    for candidate in ${cf_branches//,/ }; do
        # Nothing to process with empty repository
        if [[ -z "${repository}" ]]; then
            break
        fi
        # Split into target branch and custom field
        target=${candidate%%:*}
        cf_branch=${candidate##*:}
        # Fetch branch information
        ${basereq} --action getFieldValue \
                   --issue ${issue} \
                   --field ${cf_branch} \
                   --file "${resultfile}.branch" > /dev/null
        branch=$(cat "${resultfile}.branch")
        rm "${resultfile}.branch"

        # Branch found
        if [[ -n "${branch}" ]]; then
            branchesfound=1
            echo >> "${resultfile}.${issue}.txt"
            echo "  - Remote branch ${branch} to be integrated into upstream ${target}" | tee -a "${resultfile}.${issue}.txt"
            # Launch the prechecker for current repo and branch, waiting till it ends
            # looking for its exit code.
            set +e
            java -jar ${mydir}/../../jenkins_cli/jenkins-cli.jar -s ${jenkinsserver} \
                      build "${jenkinsjobname}" \
                      -p "remote=${repository}" -p "branch=${branch}" \
                      -p "integrateto=${target}" -p "issue=${issue}" \
                      -p "filtering=true" -p "format=html" -s > "${resultfile}.jiracli"
            status=${PIPESTATUS[0]}
            set -e
            # Let's wait artifacts to be written
            sleep 2
            # Calculate the job number and its url from output
            [[ $(head -n 1 "${resultfile}.jiracli") =~ ^Started.*#([0-9]*)$ ]]
            job=${BASH_REMATCH[1]}
            joburl="${publishserver}/job/${jenkinsjobname}/${job}"
            joburl=$(echo ${joburl} | sed 's/ /%20/g')
            rm "${resultfile}.jiracli"
            echo "    -- Executed job ${joburl}" | tee -a "${resultfile}.${issue}.txt"
            echo "    -- Execution status: ${status}"
            # Fetch the errors.txt file and add its contents to output
            set +e
            errors=$(curl --silent --fail "${joburl}/artifact/work/errors.txt")
            curlstatus=${PIPESTATUS[0]}
            set -e
            if [[ ! -z "${errors}" ]] && [[ ${curlstatus} -eq 0 ]]; then
                perrors=$(echo "${errors}" | sed 's/^/    -- /g')
                echo "${perrors}" | tee -a "${resultfile}.${issue}.txt"
            fi
            # TODO: Print any summary information
            # Finally link to the results file
            if [[ ${status} -eq 0 ]]; then
                echo "    -- Details: ${joburl}/artifact/work/smurf.html" | tee -a "${resultfile}.${issue}.txt"
            fi
        fi
    done
    # Verify we have processed some branch.
    if [[ ! -z  "${repository}" ]] && [[ -z "${branchesfound}" ]]; then
        echo "  - Error: all the branch fields are incorrect. Nothing was checked." | tee -a "${resultfile}.${issue}.txt"
    fi
    # Execute the criteria postissue. It will perform the needed changes in the tracker for the current issue
    if [[ ${quiet} == "false" ]]; then
        echo "  - Sending results to the Tracker"
        . "${mydir}/criteria/${criteria}/postissue.sh"
    fi
done < "${resultfile}"

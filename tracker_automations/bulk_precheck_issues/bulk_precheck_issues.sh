#!/usr/bin/env bash
# Look all reopened issues under current integration and move them out
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#cf_repository: id for "Pull from Repository" custom field (customfield_10100)
#cf_branches: pairs of moodle branch and id for "Pull XXXX Branch" custom field (master:customfield_10111,....)
#cf_testinginstructions: id for testing instructions custom field (customfield_10117)
#criteria: "awaiting peer review", "awaiting integration", "developer request"
#informtofiles: comma separated list of files where each MDL processed will be informed (format MDL-xxxx unixseconds)
#$maxcommitswarn: Max number of commits accepted per run. Warning if exceeded. Defaults to 10.
#$maxcommitserror: Max number of commits accepted per run. Error if exceeded. Defaults to 100.
#quiet: if enabled ("true"), don't perform any action in the Tracker.
#jenkinsjobname: job in the server that we are going to execute
#jenkinsserver: private jenkins server url (where the prechecker will be executed.
#               note this must be a direct url. no proxies/rewrites/redirects allowed. Usually http://localhost:8080.
#publishserver: public jenkins server url (where result will be available).
#               note this can be behind proxies, redirects... Public URL like http://integration.moodle.org.

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass cf_repository cf_branches cf_testinginstructions criteria quiet jenkinsjobname jenkinsserver publishserver"
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

# Apply some defaults
maxcommitswarn=${maxcommitswarn:-10}
maxcommitserror=${maxcommitserror:-100}

# Include some utility functions
. "${mydir}/util.sh"

# Execute the criteria query. It will save a list of issues (format 101) to $resultfile.
. "${mydir}/criteria/${criteria}/query.sh"

# Some criteria might want to override default settings.
if [[ -f "${mydir}/criteria/${criteria}/override-defaults.sh" ]]; then
    echo "Applying additional defaults from criteria: ${criteria}"
    . "${mydir}/criteria/${criteria}/override-defaults.sh"
fi

# Iterate over found issues and launch the prechecker for them
while read issue; do
    issueresult="success"
    echo -n > "${resultfile}.${issue}.txt"
    echo "Results for ${issue} (https://tracker.moodle.org/browse/${issue})"
    # Fetch repository
    ${basereq} --action getFieldValue \
               --issue ${issue} \
               --field ${cf_repository} \
               --file "${resultfile}.repository" > /dev/null
    repository=$(cat "${resultfile}.repository" | tr -d ' ')
    rm "${resultfile}.repository"
    if [[ -z "${repository}" ]]; then
        issueresult="error"
        echo "  (x) Error: the repository field is empty. Nothing was checked." | tee -a "${resultfile}.${issue}.txt"
    else
        echo "  Checked ${issue} using repository: ${repository}" | tee -a "${resultfile}.${issue}.txt"
    fi

    # Check if there are testing instructions
    ${basereq} --action getFieldValue \
               --issue ${issue} \
               --field ${cf_testinginstructions} \
               --file "${resultfile}.testinginstructions" > /dev/null
    testinginstructions=$(cat "${resultfile}.testinginstructions")
    rm "${resultfile}.testinginstructions"
    if [[ -z "${testinginstructions}" ]]; then
        issueresult="error"
        echo " - (x) Testing instructions are missing." | tee -a "${resultfile}.${issue}.txt"
    fi
    # Iterate over the candidate branches
    branchesfound=""
    for candidate in ${cf_branches//,/ }; do
        branchresult="success"
        branchcolor="green"
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
        branch=$(cat "${resultfile}.branch" | tr -d ' ')
        rm "${resultfile}.branch"

        # Branch found
        if [[ -n "${branch}" ]]; then
            branchesfound=1
            # Launch the prechecker for current repo and branch, waiting till it ends
            # looking for its exit code.
            set +e
            java -jar ${mydir}/../../jenkins_cli/jenkins-cli.jar -s ${jenkinsserver} \
                      build "${jenkinsjobname}" \
                      -p "remote=${repository}" -p "branch=${branch}" \
                      -p "integrateto=${target}" -p "issue=${issue}" \
                      -p "filtering=true" -p "format=html" \
                      -p "maxcommitswarn=${maxcommitswarn}" -p "maxcommitserror=${maxcommitserror}" \
                      -s -v > "${resultfile}.jiracli" < /dev/null
            status=${PIPESTATUS[0]}
            set -e
            # Let's wait artifacts to be written
            sleep 2
            # Calculate the job number and its url from output
            [[ $(head -n 1 "${resultfile}.jiracli") =~ ^Started.*#([0-9]*)$ ]]
            job=${BASH_REMATCH[1]}
            joburl="${publishserver}/job/${jenkinsjobname}/${job}"
            joburl=$(echo ${joburl} | sed 's/ /%20/g')
            branchlink="[${branch}|${joburl}/artifact/work/patchset.diff]"

            # Decide prechecker/smurf result
            if grep -q "SMURFRESULT: smurf,success" "${resultfile}.jiracli"; then
                smurfresult="success"
            elif grep -q "SMURFRESULT: smurf,warning" "${resultfile}.jiracli"; then
                smurfresult="warning"
            else
                smurfresult="error"
            fi

            # Within the branch things only can become worse
            if [[ ${smurfresult} == "warning" ]] && [[ ${branchresult} == "success" ]]; then
                branchresult="warning"
                branchcolor="orange"
            elif [[ ${smurfresult} == "error" ]]; then
                branchresult="error"
                branchcolor="red"
            fi

            # Only if SMURFRESULT arrived, calculate different parts
            condensedresult=''
            details=''
            totalcounters=''
            if grep -q "SMURFRESULT: smurf," "${resultfile}.jiracli"; then
                condensedresult=$(sed -n -e 's/.*SMURFRESULT: \(smurf,.*\)/\1/p' "${resultfile}.jiracli")
                # Extract total errors and warnings
                [[ ${condensedresult} =~ smurf,[^,]*,([^,]*),([^,:]*): ]]
                errors=${BASH_REMATCH[1]}
                warnings=${BASH_REMATCH[2]}
                totalcounters="(${errors} errors / ${warnings} warnings)"
                # Extract details, spliting, coloring and linking them
                [[ ${condensedresult} =~ smurf,.*:(.*) ]]
                detailslist=${BASH_REMATCH[1]};
                while [[ "${detailslist}" ]]; do
                    testcolor="green"
                    detail="${detailslist%%;*}"
                    if [[ -n "${detail}" ]]; then
                        [[ ${detail} =~ ([^,]*),([^,]*),([^,]*),([^,]*) ]]
                        testname=${BASH_REMATCH[1]}
                        testresult=${BASH_REMATCH[2]}
                        errors=${BASH_REMATCH[3]}
                        warnings=${BASH_REMATCH[4]}
                        if [[ ${testresult} == "warning" ]]; then
                            testcolor="orange"
                        elif [[ ${testresult} == "error" ]]; then
                            testcolor="red"
                        fi
                        details="${details} [{color:${testcolor}}${testname} (${errors}/${warnings}){color}|${joburl}/artifact/work/smurf.html#${testname}],"
                    fi
                    if [[ "${detailslist}" == "${detail}" ]]; then
                        detailslist=''
                    else
                        detailslist="${detailslist#*;}"
                    fi
                done
            fi
            rm "${resultfile}.jiracli"

            # TODO: Print any summary information
            # Finally link to the results file
            if [[ ${status} -eq 0 ]]; then

                # Output for Jira:
                if [[ ${smurfresult} == "success" ]]; then
                    echo -n " - (/)"  >> "${resultfile}.${issue}.txt"
                elif [[ ${smurfresult} == "warning" ]]; then
                    echo -n " - (!)"  >> "${resultfile}.${issue}.txt"
                else
                    echo -n " - (x)"  >> "${resultfile}.${issue}.txt"
                fi

                # Output for Jira
                echo " {color:${branchcolor}}${target} ${totalcounters}{color} [branch: ${branchlink} | [CI Job|${joburl}]]" >> "${resultfile}.${issue}.txt"
                # Output for console
                echo "    - Checked ${branch} for ${target} exit status: ${status}"

                # Output details
                if [[ -n ${details} ]]; then
                    # Output for Jira, but not if success.
                    if [[ ${smurfresult} != "success" ]]; then
                        echo "  -- ${details}" >> "${resultfile}.${issue}.txt"
                    fi
                    # Output for console
                    echo "      -- ${condensedresult}"
                fi
            else
                branchresult="error"
                # Output for Jira:
                echo "    - (x) {color:red}${target}{color} [branch: ${branchlink} | [CI Job|${joburl}]]" >> "${resultfile}.${issue}.txt"
                # Output for console:
                echo "    - Checked ${branch} for ${target} exit status: ${status}"
            fi

            # Fetch the errors.txt file and add its contents to output
            set +e
            errors=$(curl --silent --fail "${joburl}/artifact/work/errors.txt")
            curlstatus=${PIPESTATUS[0]}
            set -e
            # Look if the file contains some controlled error.
            if [[ ${curlstatus} -eq 0 ]] && [[ -n $(echo "${errors}" | grep -P "(Error|Warn):") ]]; then
                # controlled errors/warnings, print them. (exclude info lines, see MDLSITE-4415)
                perrors=$(echo "${errors}" | grep -v '^Info:' | sed 's/^/    -- /g')
                echo "${perrors}" | tee -a "${resultfile}.${issue}.txt"
            elif [[ ${status} -ne 0 ]]; then
                # Failed prechecker and nothing reported via errors, generic error message
                echo "  -- CI Job exited with status ${status}. This usually means that you have found some bug in the automated prechecker. Please [report it in the Tracker|https://tracker.moodle.org/secure/CreateIssueDetails!init.jspa?pid=10020&issuetype=1&components=12431&summary=Problem%20with%20job%20XXX] or contact an integrator directly." | tee -a "${resultfile}.${issue}.txt"
            fi
        fi

        # Within the issue things only can become worse
        if [[ ${branchresult} == "warning" ]] && [[ ${issueresult} == "success" ]]; then
            issueresult="warning"
        elif [[ ${branchresult} == "error" ]]; then
            issueresult="error"
        fi
    done
    # Verify we have processed some branch.
    if [[ ! -z  "${repository}" ]] && [[ -z "${branchesfound}" ]]; then
        issueresult="error"
        echo "  (x) Error: all the branch fields are incorrect. Nothing was checked." | tee -a "${resultfile}.${issue}.txt"
    fi

    # Append a +1/-1 to the head of the file..
    if [[ ${issueresult} == "success" ]]; then
        emoticon=$(positive_tracker_emoticon)
        printf ":) *Code verified against automated checks.* ${emoticon}\n\n" | cat - "${resultfile}.${issue}.txt" > "${resultfile}.${issue}.txt.tmp"
    elif [[ ${issueresult} == "warning" ]]; then
        printf "(i) *Code verified against automated checks with warnings.*\n\n" | cat - "${resultfile}.${issue}.txt" > "${resultfile}.${issue}.txt.tmp"
    else
        emoticon=$(negative_tracker_emoticon)
        printf ":( *Fails against automated checks.* ${emoticon}\n\n" | cat - "${resultfile}.${issue}.txt" > "${resultfile}.${issue}.txt.tmp"
    fi
    mv "${resultfile}.${issue}.txt.tmp" "${resultfile}.${issue}.txt"

    # Add an information link to the bottom of the report
    echo "" >> "${resultfile}.${issue}.txt"
    if [[ ${issueresult} == "success" ]]; then
        echo "~[More information about this report|https://docs.moodle.org/dev/Automated_code_review]~" >> "${resultfile}.${issue}.txt"
    else
        echo "[Should these errors be fixed?|https://docs.moodle.org/dev/Automated_code_review#Should_coding_style_issues_in_existing_code_be_fixed.3F]" >> "${resultfile}.${issue}.txt"
    fi

    # Execute the criteria postissue. It will perform the needed changes in the tracker for the current issue
    if [[ ${quiet} == "false" ]]; then
        echo "  - Sending results to the Tracker"
        . "${mydir}/criteria/${criteria}/postissue.sh"
    fi

    # Inform to configured files about the processing of the MDL-xxxxx happenend
    if [[ -n $informtofiles ]]; then
        echo "  - Informing about the execution via files"
        for informtofile in "${informtofiles//,/ }"; do
            if [[ -w "${informtofile}" ]]; then
                echo "    - ${informtofile} updated"
                echo ${issue} $(date +%s) bulk_precheck_issues >> "${informtofile}"
            else
                echo "    - ${informtofile} NOT updated (not found/not writable)"
            fi
        done
    fi

done < "${resultfile}"

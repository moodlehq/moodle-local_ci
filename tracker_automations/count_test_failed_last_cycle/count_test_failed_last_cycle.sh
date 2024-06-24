#!/usr/bin/env bash
# Look all test-failed issues under current integration and move them out
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#integrationdate_cf: id of the 'Integration date' custom field (customfield_10210)

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass integrationdate_cf"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# temp file for intermediate storing of results
tempfile="${WORKSPACE}/count_test_failed_temp.csv"
echo -n > "${tempfile}"

# file where the last detected integration date is annotated
# with all the test_failed issues since then.
# First line = jiradate, date it was detected "yyyy/MM/dd HH:mm" and number of issues
# Next lines = List of test_failed issues
lastintegrationfile="${WORKSPACE}/count_test_failed_last_cycle.csv"

# Init the last integration file if needed (with some good date in the past)
if [ ! -f "${lastintegrationfile}" ]; then
    lastintegrationjira="2012/11/10"
    lastintegrationdate="2012/11/10 17:00"
    lastintegrationnum=0
else
    # load the contents of the last integration detected (1st line, date in tracker and date it was detected)
    lastintegrationjira=$( head -n 1 "${lastintegrationfile}" | cut -d ' ' -s -f2 )
    lastintegrationdate=$( head -n 1 "${lastintegrationfile}" | cut -d ' ' -s -f5,6 )
    lastintegrationnum=$( tail -n 1 "${lastintegrationfile}" | cut -d ' ' -s -f2 )
fi
echo "Last integration cycle ended with info ${lastintegrationjira} on ${lastintegrationdate} with ${lastintegrationnum} test_failed issues since then"

# file where all the history of integration cycles and their test_failed issues is stored
allintegrationfile="${WORKSPACE}/count_test_failed_all_cycles.csv"

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"

# Let's search the latest Integration date in the Tracker
# (we cannot get the Integration date with this query because
# it is a custom field (outputFormat = 2) and it requires
# admin provileges. For now we don't want the cibot to have them.
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND status = 'Closed' \
                 AND 'Integration date' IS NOT empty
                 ORDER BY 'Integration date' DESC" \
           --limit 1 \
           --file "${tempfile}"

# Iterate over found issues (only 1, but iterate just in case)
# and get its Integration date
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${tempfile}" ); do
    echo "Processing ${issue}"
    ${basereq} --action getFieldValue \
        --issue ${issue} \
        --field "${integrationdate_cf}" \
        --dateFormat "yyyy/MM/dd" \
        --quiet \
        --file "${tempfile}"
done

# get the contents of the integration date
integrationjira=$( cat "${tempfile}" )
integrationjira="${integrationjira//.}" # Some buggy Java AU locales come with dots in month names. Remove them.
echo "Last integration date in tracker is ${integrationjira}"

# if the last integration at jira has changed... start a new cycle
if [ "${lastintegrationjira}" != "${integrationjira}" ]; then
    # Copy all the information in lastintegrationfile to allintegrationfile
    if [ -f "${lastintegrationfile}" ]; then
        cat "${lastintegrationfile}" >> "${allintegrationfile}"
        echo >> "${allintegrationfile}"
    fi
    # Reset lastintegrationfile to new cycle information
    lastintegrationjira=${integrationjira}
    lastintegrationdate=$( date +'%Y/%m/%d %H:%M' )
    lastintegrationnum=0
    echo "Detected integration cycle closed with info ${lastintegrationjira} on ${lastintegrationdate}"
fi

# lets' look for all the test_failed issues that, being into
# any integration or testing status have been test_failed since
# we detected a new integration cycle.
lastintegrationnum=0
lastintegrationdatequoted=\'${lastintegrationdate}\'
${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
               AND status CHANGED AFTER ${lastintegrationdatequoted} FROM ( \
                   'Testing in progress',
                   'Tested') TO 'Problem during testing'" \
           --file "${tempfile}"

# Iterate over found issues, annotating them
results=''
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${tempfile}" ); do
    echo "Processing ${issue}"
    (( lastintegrationnum += 1 ))
    results="${results}\n    ${issue}"
done

# Fill lastintegrationfile contents
echo "Cycle ${integrationjira} closed on ${lastintegrationdate}" > "${lastintegrationfile}"
echo >> "${lastintegrationfile}"
echo -n "Started new cycle on ${lastintegrationdate}" >> "${lastintegrationfile}"
echo -e "${results}" >> "${lastintegrationfile}"
echo "Found ${lastintegrationnum} test-failed issues since ${lastintegrationdate}" >> "${lastintegrationfile}"

# Remove temp file
rm -fr "${tempfile}"

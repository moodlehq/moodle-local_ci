#!/usr/bin/env bash
# Look for all delayed issues since last integration cycle started
#jiraclicmd: fill execution path of the jira cli
#jiraserver: jira server url we are going to connect to
#jirauser: user that will perform the execution
#jirapass: password of the user
#integrationdate_cf: id of the 'Integration date' custom field (customfield_10210)

# Let's go strict (exit on error)
set -e

# To enable CLI output, clean this.
quiet='--quiet'

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass integrationdate_cf"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# temp file for intermediate storing of results
tempfile="${WORKSPACE}/count_delayed_temp.csv"
echo -n > "${tempfile}"

# file where the last detected integration date is annotated
# with all the delayed issues since then.
# First line = jiradate, date it was detected "yyyy/MM/dd HH:mm" and number of issues
# Next lines = List of delayed issues
lastintegrationfile="${WORKSPACE}/count_delayed_last_cycle.csv"

# Init the last integration file if needed (with some good date in the past)
if [ ! -f "${lastintegrationfile}" ]; then
    lastintegrationjira="01/Jan/14"
    lastintegrationdate="2014/01/01 17:00"
    lastintegrationnum=0
else
    # load the contents of the last integration detected (1st line, date in tracker and date it was detected)
    lastintegrationjira=$( head -n 1 "${lastintegrationfile}" | cut -d ' ' -s -f2 )
    lastintegrationdate=$( head -n 1 "${lastintegrationfile}" | cut -d ' ' -s -f5,6 )
    lastintegrationnum=$( tail -n 1 "${lastintegrationfile}" | cut -d ' ' -s -f2 )
fi
echo "Last integration cycle ended with info ${lastintegrationjira} on ${lastintegrationdate} with ${lastintegrationnum} delayed issues since then"

# file where all the history of integration cycles and their delayed issues is stored
allintegrationfile="${WORKSPACE}/count_delayed_all_cycles.csv"

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass} ${quiet}"

# Let's search the latest Integration date in the Tracker
# (we cannot get the Integration date with this query because
# it is a custom field (outputFormat = 2) and it requires
# admin provileges. For now we don't want the cibot to have them.
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Closed' \
                 AND 'Integration date' IS NOT empty
                 ORDER BY 'Integration date' DESC" \
           --limit 1 \
           --file "${tempfile}"

# Iterate over found issues (only 1, but iterate just in case)
# and get its Integration date
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${tempfile}" ); do
    echo "Calculating last integration date from Jira (looking to ${issue})"
    ${basereq} --action getFieldValue \
        --issue ${issue} \
        --field "${integrationdate_cf}" \
        --dateFormat "d/MMM/yy" \
        --file "${tempfile}"
done

# get the contents of the integration date
integrationjira=$( cat "${tempfile}" )

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

# lets' look for all the delayed issues that, being into
# any integration or testing status have been delayed (with comment) since
# we detected a new integration cycle.
lastintegrationnum=0
lastintegrationdatequoted=\'${lastintegrationdate}\'
lastintegrationdatesecs=$(date -d "${lastintegrationdate}" +%s)
${basereq} --action getIssueList \
           --search "project = 'Moodle' \
               AND status WAS IN ( \
                   'Waiting for integration review', \
                   'Integration review in progress') \
                   AFTER ${lastintegrationdatequoted} \
               AND status WAS NOT IN ( \
                   'Waiting for testing', \
                   'Testing in progress', \
                   'Tested', \
                   'Passed', \
                   'Reopened', \
                   'Closed') \
                   AFTER ${lastintegrationdatequoted}
               AND comment ~ 'The integration of this issue has been delayed until next week because'" \
           --file "${tempfile}"

# Iterate over found issues, annotating them
results=''
for issue in $( sed -n 's/^"\(MDL-[0-9]*\)".*/\1/p' "${tempfile}" ); do
    echo "Processing ${issue}"
    # Now fetch all the comments for that issue. We have to look for the delayed message comment date.
    ${basereq} --action getCommentList \
               --issue ${issue} \
               --columns Author,Created,Comment \
               --dateFormat "yyyy-MM-dd HH:mm" \
               --file "${tempfile}"
    ##--regex "The integration of this issue has been delayed until next week because" \
    ## not working till cli 7.7, so we have to filter in bash (below). JCLI-1420
    # Remove all the lines not having the delayed message (and clean CRLF)
    tr -d '\r\n' < "${tempfile}" | sed 's/""/"\n"/g' |
        grep 'The integration of this issue has been delayed until next week because' > "${tempfile}.filtered"
    mv "${tempfile}.filtered" "${tempfile}"

    # Now iterate over remaining lines, counting total of delays and delays after ${lastintegrationdate}
    total=0
    lastdate=
    lastauthor=
    while IFS=, read -r commentauthor commentdate comment
    do
        # Remove quotes from CSV
        commentauthor=${commentauthor//\"/}
        commentdate=${commentdate//\"/}
        (( total += 1 ))
        commentdatesecs=$(date -d "${commentdate}" +%s)
        echo "    $commentdate ($commentdatesecs) by $commentauthor"
        if [[ $commentdatesecs -gt $lastintegrationdatesecs ]]; then
            lastdate=${commentdate}
            lastauthor=${commentauthor}
            echo "        DELAYED! ${lastintegrationdate} ($lastintegrationdatesecs)"
        fi
    done < "${tempfile}"

    if [[ -z ${lastdate} ]]; then
        echo "    Ignoring ${issue}, it has not been recently delayed"
    else
        (( lastintegrationnum += 1 ))
        results="${results}\n    ${issue}, delayed on ${lastdate} by ${lastauthor} (${total} times delayed)"
        echo "    FOUND ${issue}, delayed on ${lastdate} by ${lastauthor} (${total} times delayed)"
    fi
done

# Fill lastintegrationfile contents
echo "Cycle ${integrationjira} closed on ${lastintegrationdate}" > "${lastintegrationfile}"
echo >> "${lastintegrationfile}"
echo -n "Started new cycle on ${lastintegrationdate}" >> "${lastintegrationfile}"
echo -e "${results}" >> "${lastintegrationfile}"
echo "Found ${lastintegrationnum} delayed issues since ${lastintegrationdate}" >> "${lastintegrationfile}"

# Remove temp file
rm -fr "${tempfile}"

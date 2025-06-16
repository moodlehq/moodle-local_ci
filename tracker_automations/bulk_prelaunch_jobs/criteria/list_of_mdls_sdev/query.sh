${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND issue IN (${issueslist}) \
                 AND \"${customfield_pullFromRepository}\" ~ 'integration/security-testing' \
                 AND level IS NOT EMPTY \
                 ORDER BY priority DESC, votes DESC, 'Last comment date' ASC" \
           --outputFormat 101 \
           --file "${resultfile}"

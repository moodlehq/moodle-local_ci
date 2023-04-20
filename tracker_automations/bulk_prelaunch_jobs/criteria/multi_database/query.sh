${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND issue IN (${issueslist}) \
                 AND level IS EMPTY \
                 ORDER BY priority DESC, votes DESC, 'Last comment date' ASC" \
           --outputFormat 101 \
           --file "${resultfile}"

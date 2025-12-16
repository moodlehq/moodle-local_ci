${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND status IN ('Waiting for integration review', 'Waiting for component lead review')  \
                 AND status WAS NOT IN ('Waiting for integration review', 'Waiting for component lead review') ON '-${schedulemins}' \
                 AND level IS EMPTY \
                 AND 'Automated test results' IS EMPTY \
                 ORDER BY priority DESC, votes DESC, 'Last comment date' ASC" \
           --outputFormat 101 \
           --file "${resultfile}"

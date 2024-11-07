${basereq} --action getIssueList \
           --jql "project = 'Moodle' \
                 AND status = 'Waiting for component lead review' \
                 AND labels NOT IN ('notobic') \
                 AND status WAS NOT 'Waiting for component lead review' ON '-${schedulemins}' \
                 AND level IS EMPTY \
                 ORDER BY priority DESC, votes DESC, 'Last comment date' ASC" \
           --outputFormat 101 \
           --file "${resultfile}"

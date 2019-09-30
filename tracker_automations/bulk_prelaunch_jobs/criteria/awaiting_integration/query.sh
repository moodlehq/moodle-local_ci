${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Waiting for integration review' \
                 AND status WAS NOT 'Waiting for integration review' ON '-${schedulemins}' \
                 AND participants not in (tobic) \
                 AND level IS EMPTY \
                 ORDER BY priority DESC, votes DESC, 'Last comment date' ASC" \
           --outputFormat 101 \
           --file "${resultfile}"

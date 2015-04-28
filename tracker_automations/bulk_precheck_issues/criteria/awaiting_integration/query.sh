${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Waiting for integration review' \
                 AND (labels IS EMPTY OR labels NOT IN (ci, security_held, integration_held)) \
                 AND level IS EMPTY \
                 ORDER BY priority DESC, votes DESC, 'Last comment date' ASC" \
           --outputFormat 101 \
           --file "${resultfile}"

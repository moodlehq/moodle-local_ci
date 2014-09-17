${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Waiting for peer review' \
                 AND (labels IS EMPTY OR labels NOT IN (ci, security_held, integration_held)) \
                 AND level IS EMPTY \
                 ORDER BY priority DESC, votes DESC" \
           --outputFormat 101 \
           --file "${resultfile}"

${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND status = 'Waiting for peer review' \
                 AND (labels IS EMPTY OR labels NOT IN (ci, security_held)) \
                 ORDER BY priority DESC, votes DESC, 'Last comment date' ASC" \
           --outputFormat 101 \
           --file "${resultfile}"

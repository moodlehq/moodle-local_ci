${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND labels IN (cime) \
                 ORDER BY priority DESC, votes DESC, 'Last comment date' ASC" \
           --outputFormat 101 \
           --file "${resultfile}"

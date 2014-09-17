${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND labels IN (cime) \
                 ORDER BY priority DESC, votes DESC" \
           --outputFormat 101 \
           --file "${resultfile}"

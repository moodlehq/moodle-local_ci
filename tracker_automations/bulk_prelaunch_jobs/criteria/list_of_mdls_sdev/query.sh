${basereq} --action getIssueList \
           --search "project = 'Moodle' \
                 AND issue IN (${issueslist}) \
                 AND cf[10100] ~ 'integration/security-testing' \
                 AND level IS NOT EMPTY \
                 ORDER BY priority DESC, votes DESC, 'Last comment date' ASC" \
           --outputFormat 101 \
           --file "${resultfile}"

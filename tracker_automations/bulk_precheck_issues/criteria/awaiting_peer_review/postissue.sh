# Add the "ci" label.
${basereq} --action addLabels \
    --issue ${issue} \
    --labels "ci"

# Add the comment with results
comment=$(cat "${resultfile}.${issue}")
${basereq} --action addComment \
    --issue ${issue} \
    --comment "${comment}"

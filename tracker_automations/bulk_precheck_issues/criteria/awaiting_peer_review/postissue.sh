# Add the "ci" label.
${basereq} --action addLabels \
    --issue ${issue} \
    --labels "ci"

# Remove the "cime" label.
${basereq} --action removeLabels \
    --issue ${issue} \
    --labels "cime"

# Add the comment with results
comment=$(cat "${resultfile}.${issue}.txt")
${basereq} --action addComment \
    --issue ${issue} \
    --comment "${comment}"

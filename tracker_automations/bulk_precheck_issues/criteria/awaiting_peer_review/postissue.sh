# Add the "ci" label.
${basereq} --action addLabels \
    --issue ${issue} \
    --labels "ci"

# Remove the "cime" label.
${basereq} --action removeLabels \
    --issue ${issue} \
    --labels "cime"

# Update the pre-check field with the results.
${basereq} --action setFieldValue \
    --issue ${issue} \
    --field "Pre-check results" \
    --file "${resultfile}.${issue}.txt"

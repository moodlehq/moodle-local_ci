# Remove the "cime" label.
${basereq} --action removeLabels \
    --issue ${issue} \
    --labels "cime CIME" # the uppercase to fix MDLSITE-4716

# Add the comment with results
comment=$(cat "${resultfile}.${issue}.txt")
${basereq} --action addComment \
    --issue ${issue} \
    --comment "${comment}"

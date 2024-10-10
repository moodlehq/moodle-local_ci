# Remove the "cime" label.
${basereq} --action removeLabels \
    --issue ${issue} \
    --labels "cime CIME Cime CiMe" # the uppercase to fix MDLSITE-4716 and cases like MDL-64431

# Update the pre-check field with the results.
${basereq} --action setFieldValue \
    --issue ${issue} \
    --field "Pre-check results" \
    --file "${resultfile}.${issue}.txt"

# Update the automated testing field with the results.
${basereq} --action setFieldValue \
    --issue ${issue} \
    --field "Automated test results" \
    --file "${resultfile}.${issue}.txt"

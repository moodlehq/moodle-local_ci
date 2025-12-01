if [[ "${post_results_in_customfield}" == "true" ]]; then
    # Update the automated testing field with the results.
    ${basereq} --action setFieldValue \
        --issue ${issue} \
        --field "Automated test results" \
        --file "${resultfile}.${issue}.txt"
else
    # Just add the results as a comment.
    ${basereq} --action addComment \
        --issue ${issue} \
        --file "${resultfile}.${issue}.txt"
fi

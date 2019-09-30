# Add the comment with results.
${basereq} --action addComment \
    --issue ${issue} \
    --file "${resultfile}.${issue}.txt" \
    --role "Integrators"

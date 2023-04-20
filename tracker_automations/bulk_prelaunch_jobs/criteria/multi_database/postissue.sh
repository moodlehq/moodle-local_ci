# Add the comment with results.
if [[ -n "${restrictedto}" ]]; then
    ${basereq} --action addComment \
        --issue ${issue} \
        --file "${resultfile}.${issue}.txt" ${restrictiontype} "${restrictedto}"
else
    ${basereq} --action addComment \
        --issue ${issue} \
        --file "${resultfile}.${issue}.txt"
fi

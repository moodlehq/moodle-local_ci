#!/usr/bin/env bash
# $WORKSPACE: Path to the directory where test reults will be sent
# $phpcmd: Path to the PHP CLI executable
# $gitcmd: Path to the git CLI executable
# $gitdir: Directory containing git repo
# $initalcommit
# $finalcommit

set -e

# Verify everything is set
required="WORKSPACE phpcmd gitcmd gitdir initialcommit finalcommit"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "ERROR: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if ${mydir}/../list_changed_files/list_changed_files.sh > ${WORKSPACE}/modified_files.txt
then
    echo "INFO: Checking for DB modifications from $initialcommit to $finalcommit"
else
    echo "ERROR: Problems getting the list of changed files."
    exit 1
fi

cd "${gitdir}"

installfound=
installcols=
upgradefound=
upgradefiles=
externalfound=
backupfound=

# Simply, iterate over the modified files, annotating what's found.
# We could do this more selectively, by components, instead of globally
# but, as far as this is only a warning, we don't need such granularity.
while read modifiedfile; do
    if [[ "${modifiedfile}" =~ db/install\.xml ]]; then
        # Try to find new columns added
        installcols=$($gitcmd diff $initialcommit $finalcommit ${modifiedfile} | sed -nr 's/^\+ *<(TABLE|FIELD) *NAME="([^"]+)".*/\2/p')
        if [[ -n ${installcols} ]]; then
            installfound=1
        fi
    fi
    if [[ "${modifiedfile}" =~ db/upgrade\.php ]]; then
        # Verify if there are new tables or columns being added.
        if [[ $($gitcmd diff $initialcommit $finalcommit ${modifiedfile} | grep 'add_field\|add_table') ]]; then
            upgradefound=1
            upgradefile=${gitdir}/${modifiedfile}
        fi
    fi
    if [[ "${modifiedfile}" =~ externallib\.php|/classes/external/ ]]; then
        externalfound=1
    fi
    if [[ "${modifiedfile}" =~ backup/moodle2/backup ]]; then
        backupfound=1
    fi

done <$WORKSPACE/modified_files.txt

# If we haven't found install and upgrade modifications adding columns or tables, everything is ok, we are done.
if [[ -z ${installfound} ]] || [[ -z ${upgradefound} ]]; then
    echo "INFO: OK the patch does not include new tables or columns"
    exit 0
fi

# Arrived here, we have found new tables or columns coming in the patch. Let's look for usual missing stuff.
echo "INFO: The patch does include new tables or columns"

if [[ -z ${externalfound} ]] || [[ -z ${backupfound} ]]; then
    echo "${upgradefile} - WARN: Database modifications (new tables or columns) detected in the patch without any change to some important areas."

    if [[ -z ${externalfound} ]]; then
        echo "${upgradefile} - WARN: No changes detected to external functions, that may affect apps and other web service integrations, please verify!"
    fi

    if [[ -z ${backupfound} ]]; then
        echo "${upgradefile} - WARN: No changes detected to backup and restore, that may affect storage and transportability, please verify!"
    fi
else
    echo "INFO: OK the patch includes changes to both external and backup code"
fi

exit 0
